// Sources/Dendrite/Core/HierarchicalChunker.swift

import Foundation
import NaturalLanguage
import OSLog

// MARK: - Chunk Buffer

/// 청크 생성 전 노드들을 임시로 저장하는 버퍼입니다.
private struct ChunkBuffer: Sendable {
    private(set) var nodes: [SemanticNode] = []
    private(set) var tokenCount: TokenCount = 0
    private(set) var breadcrumb: Breadcrumb
    private(set) var sourceNodeIDs: Set<NodeID> = []
    
    init(breadcrumb: Breadcrumb) {
        self.breadcrumb = breadcrumb
    }
    
    mutating func add(node: SemanticNode, tokens: TokenCount) {
        nodes.append(node)
        tokenCount = tokenCount + tokens
        if let nodeID = node.id {
            sourceNodeIDs.insert(NodeID(nodeID))
        }
    }
    
    mutating func updateBreadcrumb(_ newBreadcrumb: Breadcrumb) {
        self.breadcrumb = newBreadcrumb
    }
    
    var isEmpty: Bool {
        nodes.isEmpty
    }
    
    var content: String {
        nodes.map { $0.plainText }.joined(separator: "\n\n")
    }
    
    mutating func clear() {
        nodes.removeAll()
        tokenCount = 0
        sourceNodeIDs.removeAll()
    }
}

// MARK: - Hierarchical Chunker

/// 고급 계층적 청킹 엔진입니다.
///
/// 이 액터는 `SemanticNode` 트리를 의미론적으로 일관된 청크로 변환합니다.
/// 테이블, 코드 블록 등의 특수 콘텐츠를 최적화하여 처리하며,
/// 컨텍스트 보존과 검색 품질 향상을 위한 고급 기능을 제공합니다.
public actor HierarchicalChunker {
    
    // MARK: - Properties
    
    private let tokenizer: any Tokenizer
    private let configuration: DendriteConfig.Chunking
    private let logger = Logger(subsystem: "Dendrite.Core", category: "HierarchicalChunker")
    
    // MARK: - Internal State (managed by the actor)
    
    private var chunkIndex: Int = 0
    private var processedNodeCount: Int = 0
    private var totalTokenCount: TokenCount = 0
    
    // MARK: - Initialization
    
    public init(
        tokenizer: any Tokenizer,
        configuration: DendriteConfig.Chunking = .default
    ) {
        self.tokenizer = tokenizer
        self.configuration = configuration
        
        logger.info("HierarchicalChunker initialized with config: max=\(configuration.maxTokensPerChunk), min=\(configuration.minTokensPerChunk)")
    }
    
    // MARK: - Public Interface
    
    /// 노드 배열을 청크로 변환합니다.
    public func chunk(
        nodes: [SemanticNode],
        documentId: DocumentID,
        metadata: DocumentMetadata
    ) async throws -> [Chunk] {
        logger.info("Starting chunking process for document: \(documentId.value)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 각 청킹 프로세스마다 내부 상태를 초기화합니다.
        self.chunkIndex = 0
        self.processedNodeCount = 0
        self.totalTokenCount = 0
        
        do {
            let chunks = try await performChunking(
                nodes: nodes,
                documentId: documentId,
                metadata: metadata
            )
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let processingTime = endTime - startTime
            
            logChunkingResults(chunks: chunks, processingTime: processingTime)
            
            return chunks
        } catch {
            logger.error("Chunking failed: \(error.localizedDescription)")
            throw ChunkingError.processingFailed(error)
        }
    }
    
    // MARK: - Core Chunking Logic
    
    private func performChunking(
        nodes: [SemanticNode],
        documentId: DocumentID,
        metadata: DocumentMetadata
    ) async throws -> [Chunk] {
        var chunks: [Chunk] = []
        let initialBreadcrumb = createInitialBreadcrumb(from: metadata)
        var buffer = ChunkBuffer(breadcrumb: initialBreadcrumb)
        var breadcrumbStack = BreadcrumbStack(initial: initialBreadcrumb)
        
        for node in nodes {
            self.processedNodeCount += 1
            
            // 컨텍스트 경계 처리
            if node.isContextBoundary {
                if !buffer.isEmpty {
                    let chunk = try await createChunk(from: buffer, documentId: documentId, metadata: metadata)
                    chunks.append(chunk)
                    buffer.clear()
                }
                
                // 브레드크럼 업데이트
                if case .heading(let level, let text, _, _) = node {
                    breadcrumbStack.updateForHeading(level: level, text: text)
                    buffer.updateBreadcrumb(breadcrumbStack.current)
                }
            }
            
            // 특수 노드 처리
            if configuration.enableSpecialHandling && node.requiresSpecialHandling {
                let specialChunks = try await handleSpecialNode(
                    node,
                    documentId: documentId,
                    metadata: metadata,
                    breadcrumb: breadcrumbStack.current
                )
                chunks.append(contentsOf: specialChunks)
                continue
            }
            
            // 일반 노드 처리
            try await processRegularNode(
                node,
                buffer: &buffer,
                chunks: &chunks,
                documentId: documentId,
                metadata: metadata
            )
        }
        
        // 마지막 버퍼 처리
        if !buffer.isEmpty {
            let chunk = try await createChunk(from: buffer, documentId: documentId, metadata: metadata)
            chunks.append(chunk)
        }
        
        return try await applyPostProcessing(chunks: chunks)
    }
    
    // MARK: - Node Processing
    
    private func processRegularNode(
        _ node: SemanticNode,
        buffer: inout ChunkBuffer,
        chunks: inout [Chunk],
        documentId: DocumentID,
        metadata: DocumentMetadata
    ) async throws {
        let nodeText = node.plainText
        let nodeTokens = await tokenizer.countTokens(in: nodeText)
        
        self.totalTokenCount = self.totalTokenCount + nodeTokens
        
        // 노드가 너무 큰 경우 분할
        if nodeTokens.value > configuration.maxTokensPerChunk {
            if !buffer.isEmpty {
                let chunk = try await createChunk(from: buffer, documentId: documentId, metadata: metadata)
                chunks.append(chunk)
                buffer.clear()
            }
            
            let splitChunks = try await splitLargeNode(
                node,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: buffer.breadcrumb
            )
            chunks.append(contentsOf: splitChunks)
            return
        }
        
        // 버퍼에 추가했을 때 크기 초과 여부 확인
        if (buffer.tokenCount + nodeTokens).value > configuration.maxTokensPerChunk {
            if !buffer.isEmpty {
                let chunk = try await createChunk(from: buffer, documentId: documentId, metadata: metadata)
                chunks.append(chunk)
                buffer.clear()
            }
        }
        
        buffer.add(node: node, tokens: nodeTokens)
    }
    
    // MARK: - Special Node Handling
    
    private func handleSpecialNode(
        _ node: SemanticNode,
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb
    ) async throws -> [Chunk] {
        switch node {
        case .table(let caption, let headers, let rows, _, _):
            return try await handleTableNode(
                caption: caption,
                headers: headers,
                rows: rows,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: breadcrumb
            )
            
        case .codeBlock(let language, let code, _, _):
            return try await handleCodeBlockNode(
                language: language,
                code: code,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: breadcrumb
            )
            
        default:
            return []
        }
    }
    
    private func handleTableNode(
        caption: String?,
        headers: [String],
        rows: [[String]],
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb
    ) async throws -> [Chunk] {
        var chunks: [Chunk] = []
        let tableBreadcrumb = breadcrumb.appending("Table")
        
        // 테이블 구조 정보 청크
        let structureInfo = createTableStructureInfo(caption: caption, headers: headers, rowCount: rows.count)
        let structureChunk = try await createSingleChunk(
            content: structureInfo,
            documentId: documentId,
            metadata: metadata,
            breadcrumb: tableBreadcrumb.appending("Structure")
        )
        chunks.append(structureChunk)
        
        // 각 행을 개별 청크로 처리
        for (index, row) in rows.enumerated() {
            let rowContent = createTableRowContent(headers: headers, row: row, caption: caption)
            let rowChunk = try await createSingleChunk(
                content: rowContent,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: tableBreadcrumb.appending("Row \(index + 1)")
            )
            chunks.append(rowChunk)
        }
        
        return chunks
    }
    
    private func handleCodeBlockNode(
        language: String?,
        code: String,
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb
    ) async throws -> [Chunk] {
        let codeBreadcrumb = breadcrumb.appending("Code")
        let codeTokens = await tokenizer.countTokens(in: code)
        
        if codeTokens.value > configuration.maxTokensPerChunk {
            return try await splitCodeBlock(
                code: code,
                language: language,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: codeBreadcrumb
            )
        }
        
        let formattedCode = formatCodeBlock(code: code, language: language)
        let codeChunk = try await createSingleChunk(
            content: formattedCode,
            documentId: documentId,
            metadata: metadata,
            breadcrumb: codeBreadcrumb
        )
        
        return [codeChunk]
    }
    
    // MARK: - Chunk Creation
    
    private func createChunk(
        from buffer: ChunkBuffer,
        documentId: DocumentID,
        metadata: DocumentMetadata
    ) async throws -> Chunk {
        guard !buffer.isEmpty else {
            throw ChunkingError.emptyBuffer
        }
        
        let content = buffer.content
        let tokenCount = await tokenizer.countTokens(in: content)
        
        let qualityScore = calculateQualityScore(content: content, tokenCount: tokenCount, nodes: buffer.nodes)
        
        return Chunk(
            id: ChunkID.generate(documentId: documentId, index: incrementChunkIndex()),
            documentId: documentId,
            content: content,
            tokenCount: tokenCount,
            breadcrumb: buffer.breadcrumb,
            sourceNodeIDs: buffer.sourceNodeIDs,
            documentMetadata: metadata,
            qualityScore: qualityScore
        )
    }
    
    private func createSingleChunk(
        content: String,
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb,
        sourceNodeIDs: Set<NodeID> = []
    ) async throws -> Chunk {
        let tokenCount = await tokenizer.countTokens(in: content)
        
        let qualityScore = calculateQualityScore(content: content, tokenCount: tokenCount, nodes: [])
        
        return Chunk(
            id: ChunkID.generate(documentId: documentId, index: incrementChunkIndex()),
            documentId: documentId,
            content: content,
            tokenCount: tokenCount,
            breadcrumb: breadcrumb,
            sourceNodeIDs: sourceNodeIDs,
            documentMetadata: metadata,
            qualityScore: qualityScore
        )
    }
    
    // MARK: - Content Splitting
    
    private func splitLargeNode(
        _ node: SemanticNode,
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb
    ) async throws -> [Chunk] {
        let nodeText = node.plainText
        let splitTexts = await tokenizer.split(
            text: nodeText,
            maxTokens: configuration.maxTokensPerChunk - configuration.overlapTokens,
            by: configuration.splitUnit
        )
        
        var chunks: [Chunk] = []
        var previousOverlap = ""
        
        let sourceNodeID = node.id.map { NodeID($0) }
        
        for (index, text) in splitTexts.enumerated() {
            var chunkContent = text
            
            if configuration.preserveContext && index > 0 && !previousOverlap.isEmpty {
                chunkContent = previousOverlap + "\n\n" + text
            }
            
            let chunk = try await createSingleChunk(
                content: chunkContent,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: breadcrumb.appending("Part \(index + 1)"),
                sourceNodeIDs: sourceNodeID.map { [$0] } ?? []
            )
            chunks.append(chunk)
            
            if configuration.overlapTokens > 0 && index < splitTexts.count - 1 {
                previousOverlap = await extractOverlapText(from: text, tokens: configuration.overlapTokens)
            }
        }
        
        return chunks
    }
    
    private func splitCodeBlock(
        code: String,
        language: String?,
        documentId: DocumentID,
        metadata: DocumentMetadata,
        breadcrumb: Breadcrumb
    ) async throws -> [Chunk] {
        let lines = code.components(separatedBy: .newlines)
        var chunks: [Chunk] = []
        var currentLines: [String] = []
        var currentTokens = 0
        
        for line in lines {
            let lineTokens = await tokenizer.countTokens(in: line).value
            
            if currentTokens + lineTokens > configuration.maxTokensPerChunk && !currentLines.isEmpty {
                let codeContent = formatCodeBlock(code: currentLines.joined(separator: "\n"), language: language)
                let chunk = try await createSingleChunk(
                    content: codeContent,
                    documentId: documentId,
                    metadata: metadata,
                    breadcrumb: breadcrumb.appending("Part \(chunks.count + 1)")
                )
                chunks.append(chunk)
                
                currentLines = []
                currentTokens = 0
            }
            
            currentLines.append(line)
            currentTokens += lineTokens
        }
        
        if !currentLines.isEmpty {
            let codeContent = formatCodeBlock(code: currentLines.joined(separator: "\n"), language: language)
            let chunk = try await createSingleChunk(
                content: codeContent,
                documentId: documentId,
                metadata: metadata,
                breadcrumb: breadcrumb.appending("Part \(chunks.count + 1)")
            )
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    // MARK: - Quality Assessment
    
    private func calculateQualityScore(
        content: String,
        tokenCount: TokenCount,
        nodes: [SemanticNode]
    ) -> Double {
        var score = 1.0
        
        let tokenRatio = Double(tokenCount.value) / Double(configuration.maxTokensPerChunk)
        if tokenRatio < 0.1 { score *= 0.7 }
        else if tokenRatio > 0.9 { score *= 0.9 }
        
        if !nodes.isEmpty {
            let avgImportance = nodes.map(\.structuralImportance).reduce(0, +) / Double(nodes.count)
            score = (score + avgImportance) / 2.0
        }
        
        let contentScore = assessContentQuality(content)
        score = (score + contentScore) / 2.0
        
        return max(0.0, min(1.0, score))
    }
    
    private func assessContentQuality(_ content: String) -> Double {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty { return 0.0 }
        if trimmed.count < 10 { return 0.3 }
        
        var score = 0.7
        
        let sentences = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let completeSentences = sentences.filter {
            let trimmedSentence = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedSentence.count > 5 && trimmedSentence.first?.isLetter == true
        }
        
        if completeSentences.count > 0 { score += 0.2 }
        
        if trimmed.contains(":") || trimmed.contains("-") || trimmed.contains("•") { score += 0.1 }
        
        return min(1.0, score)
    }
    
    // MARK: - Post Processing
    
    private func applyPostProcessing(chunks: [Chunk]) async throws -> [Chunk] {
        let filteredChunks = chunks.filter {
            $0.qualityScore >= configuration.qualityThreshold &&
            $0.tokenCount.value >= configuration.minTokensPerChunk
        }
        
        logger.info("Post-processing: \(chunks.count) -> \(filteredChunks.count) chunks")
        
        return filteredChunks
    }
    
    // MARK: - Helper Methods
    
    private func createInitialBreadcrumb(from metadata: DocumentMetadata) -> Breadcrumb {
        Breadcrumb([metadata.title ?? "Document"])
    }
    
    private func createTableStructureInfo(caption: String?, headers: [String], rowCount: Int) -> String {
        var info = "Table Information:\n"
        if let caption = caption, !caption.isEmpty { info += "Caption: \(caption)\n" }
        info += "Headers: \(headers.joined(separator: ", "))\n"
        info += "Rows: \(rowCount)\n"
        info += "Structure: \(headers.count) columns × \(rowCount) rows"
        return info
    }
    
    private func createTableRowContent(headers: [String], row: [String], caption: String?) -> String {
        var content = ""
        if let caption = caption, !caption.isEmpty { content += "Table: \(caption)\n" }
        
        let rowData = zip(headers, row).map { "\($0): \($1)" }.joined(separator: ", ")
        content += "Row: { \(rowData) }"
        
        return content
    }
    
    private func formatCodeBlock(code: String, language: String?) -> String {
        var formatted = "Code"
        if let language = language, !language.isEmpty { formatted += " (\(language))" }
        formatted += ":\n\(code)"
        return formatted
    }
    
    private func extractOverlapText(from text: String, tokens: Int) async -> String {
        let sentences = text.components(separatedBy: ". ")
        if sentences.count <= 1 {
            return String(text.suffix(min(text.count, 200)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        var overlap = ""
        var currentTokens = 0
        
        for sentence in sentences.reversed() {
            let sentenceTokens = await tokenizer.countTokens(in: sentence).value
            if currentTokens + sentenceTokens > tokens { break }
            overlap = sentence + ". " + overlap
            currentTokens += sentenceTokens
        }
        
        return overlap.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func logChunkingResults(chunks: [Chunk], processingTime: Double) {
        guard !chunks.isEmpty else {
            logger.info("Chunking completed with 0 chunks.")
            return
        }
        
        let totalTokens = chunks.reduce(0) { $0 + $1.tokenCount.value }
        let avgTokensPerChunk = totalTokens / chunks.count
        let avgQuality = chunks.map(\.qualityScore).reduce(0, +) / Double(chunks.count)
        
        logger.info("""
        Chunking completed:
        - Chunks: \(chunks.count)
        - Total tokens: \(totalTokens)
        - Avg tokens/chunk: \(avgTokensPerChunk)
        - Avg quality: \(String(format: "%.2f", avgQuality))
        - Processing time: \(String(format: "%.2f", processingTime))s
        - Nodes processed: \(self.processedNodeCount)
        """)
    }
    
    private func incrementChunkIndex() -> Int {
        defer { chunkIndex += 1 }
        return chunkIndex
    }
}

// MARK: - Breadcrumb Stack

/// 계층적 브레드크럼 관리를 위한 스택입니다.
private struct BreadcrumbStack {
    private var components: [String]
    
    init(initial: Breadcrumb) {
        self.components = initial.components
    }
    
    var current: Breadcrumb {
        Breadcrumb(components)
    }
    
    mutating func updateForHeading(level: Int, text: String) {
        // 현재 헤딩 레벨에 맞게 스택을 조정합니다.
        // 예를 들어, h2 다음에 h3가 오면 스택에 추가되고,
        // 다시 h2가 오면 기존 h2와 h3를 모두 제거하고 새로운 h2를 추가합니다.
        while components.count >= level {
            components.removeLast()
        }
        components.append(text)
    }
}

// MARK: - Error Types

/// 청킹 과정에서 발생할 수 있는 오류들입니다.
public enum ChunkingError: Error, LocalizedError {
    case emptyBuffer
    case processingFailed(Error)
    case invalidConfiguration
    case tokenizationFailed
    
    public var errorDescription: String? {
        switch self {
        case .emptyBuffer: "청크 버퍼가 비어있어 청크를 생성할 수 없습니다."
        case .processingFailed(let error): "청킹 처리 중 오류가 발생했습니다: \(error.localizedDescription)"
        case .invalidConfiguration: "청킹 설정이 유효하지 않습니다."
        case .tokenizationFailed: "토큰화 작업이 실패했습니다."
        }
    }
}
