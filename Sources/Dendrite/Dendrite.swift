// Sources/Dendrite/Dendrite.swift

import Foundation
import UniformTypeIdentifiers

// MARK: - Processed Document Model

/// `Dendrite` 라이브러리의 최종 처리 결과물을 담는 구조체입니다.
/// 이 객체는 파싱된 전체 노드 트리, 의미 단위로 분할된 청크, 그리고 다양한 통계 정보를 포함합니다.
public struct ProcessedDocument: Sendable {
    /// 문서의 고유 식별자입니다。
    public let id: DocumentID
    /// 문서에서 추출된 메타데이터입니다。
    public let metadata: DocumentMetadata
    /// 파싱된 `SemanticNode`의 전체 트리입니다。
    public let nodes: [SemanticNode]
    /// 의미 단위로 분할된 `Chunk`의 배열입니다。
    public let chunks: [Chunk]
    /// 처리에 소요된 시간, 토큰 수 등의 통계 정보입니다。
    public let statistics: ProcessingStatistics
}

/// 문서 처리 과정에 대한 통계 정보를 담는 구조체입니다。
public struct ProcessingStatistics: Sendable {
    /// 총 처리 시간 (초) 입니다。
    public let processingTime: TimeInterval
    /// 문서 전체의 총 토큰 수 입니다。
    public let totalTokenCount: TokenCount
    /// 생성된 청크의 총 개수입니다。
    public let chunkCount: Int
    /// 청크 당 평균 토큰 수 입니다。
    public let averageTokensPerChunk: TokenCount
}

// MARK: - Main API Namespace

/// 다양한 형식의 문서를 파싱하고 변환하는 라이브러리의 메인 API 네임스페이스입니다.
public enum Dendrite {
    
    /// 지정된 URL의 파일을 처리하여, 파싱된 노드, 의미 단위 청크, 메타데이터를 포함하는 `ProcessedDocument`를 반환합니다.
    ///
    /// - Parameters:
    ///   - url: 처리할 파일의 URL
    ///   - documentId: 문서에 부여할 고유 ID. `nil`인 경우 파일 이름을 사용합니다.
    ///   - config: 처리 과정을 제어하는 설정 객체. 청크 크기, 파서 등을 지정할 수 있습니다.
    ///   - tokenizer: 청킹 시 토큰 수 계산에 사용할 `Tokenizer` 인스턴스.
    /// - Returns: `ProcessedDocument` 객체
    public static func process(
        from url: URL,
        documentId: DocumentID? = nil,
        config: DendriteConfig = .default,
        tokenizer: any Tokenizer
    ) async throws -> ProcessedDocument {
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DendriteError.fileReadFailed(url: url, underlyingError: error)
        }
        
        let fileType = UTType(filenameExtension: url.pathExtension)
        let docId = documentId ?? DocumentID(url.lastPathComponent)
        
        // 1. 메타데이터 빌더 생성 및 범용 정보 채우기
        let metadataBuilder = DocumentMetadataBuilder()
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
            metadataBuilder
                .fileSize(resourceValues.fileSize)
                .creationDate(resourceValues.creationDate)
                .modificationDate(resourceValues.contentModificationDate)
                .mimeType(UTType(filenameExtension: url.pathExtension)?.preferredMIMEType)
        } catch {
            // 리소스 값 가져오기 실패는 치명적이지 않음, 로깅만 하고 계속 진행
            print("Warning: Could not retrieve file resource values for \(url.path): \(error)")
        }
        
        return try await process(data: data, fileType: fileType, documentId: docId, config: config, tokenizer: tokenizer, metadataBuilder: metadataBuilder)
    }
    
    /// 메모리에 있는 `Data`를 처리하여, `ProcessedDocument`를 반환합니다.
    public static func process(
        data: Data,
        fileType: UTType?,
        documentId: DocumentID,
        config: DendriteConfig = .default,
        tokenizer: any Tokenizer,
        metadataBuilder: DocumentMetadataBuilder = DocumentMetadataBuilder() // URL이 없을 경우를 위한 기본 빌더
    ) async throws -> ProcessedDocument {
        
        let startTime = Date()
        
        guard let fileType = fileType else {
            throw DendriteError.unsupportedFileType(fileExtension: "unknown")
        }
        
        guard let parser = ParserFactory.parser(for: fileType, availableParsers: config.parsers) else {
            throw DendriteError.unsupportedFileType(fileExtension: fileType.preferredFilenameExtension ?? "unknown")
        }
        
        // 1. 파싱 (메타데이터 빌더 전달)
        let (nodes, metadata) = try await parser.parse(data: data, type: fileType, metadataBuilder: metadataBuilder)
        
        // 2. 청킹
        let chunker = HierarchicalChunker(tokenizer: tokenizer, configuration: config.chunking) // 수정됨
        let chunks = try await chunker.chunk(nodes: nodes, documentId: documentId, metadata: metadata)
        
        // 3. 통계 계산 및 최종 결과물 조립
        let processingTime = Date().timeIntervalSince(startTime)
        let totalTokens = chunks.reduce(0) { $0 + $1.tokenCount.value }
        let stats = ProcessingStatistics(
            processingTime: processingTime,
            totalTokenCount: TokenCount(totalTokens),
            chunkCount: chunks.count,
            averageTokensPerChunk: chunks.isEmpty ? TokenCount(0) : TokenCount(totalTokens / chunks.count)
        )
        
        return ProcessedDocument(
            id: documentId,
            metadata: metadata,
            nodes: nodes,
            chunks: chunks,
            statistics: stats
        )
    }
}
