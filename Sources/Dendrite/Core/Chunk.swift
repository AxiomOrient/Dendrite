// Sources/Dendrite/Core/Chunk.swift

import Foundation
import CryptoKit
import OSLog

// MARK: - Chunk Entity

/// 의미론적 단위로 분할된 문서의 조각(Chunk)을 나타내는 불변 구조체입니다.
///
/// 이 구조체는 RAG 파이프라인의 임베딩 및 검색 단계에서 사용될 핵심 데이터 모델입니다.
/// 완전한 불변성(immutability)과 값 타입 의미론을 통해 동시성 환경에서 안전하게 사용됩니다.
///
/// ## 설계 원칙
/// - **불변성**: 생성 후 모든 프로퍼티가 변경되지 않음
/// - **값 의미론**: 동시성 환경에서 안전한 복사 및 전달
/// - **타입 안전성**: 컴파일 타임에 잘못된 사용 방지
/// - **성능 최적화**: 메모리 효율적인 설계
@frozen
public struct Chunk: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// 청크의 고유 식별자 (예: "document1_chunk_5")
    public let id: ChunkID
    
    /// 이 청크가 속한 원본 문서의 식별자
    public let documentId: DocumentID
    
    /// 임베딩에 사용될, 서식이 제거된 순수 텍스트 내용
    public let content: String
    
    /// 이 청크의 정확한 토큰 수
    public let tokenCount: TokenCount
    
    /// 문서 내에서 이 청크의 계층적 위치를 나타내는 경로
    public let breadcrumb: Breadcrumb
    
    /// 이 청크를 구성하는 원본 SemanticNode들의 ID 집합
    public let sourceNodeIDs: Set<NodeID>
    
    /// 이 청크와 관련된 문서의 전역 메타데이터
    public let documentMetadata: DocumentMetadata
    
    /// 청크 생성 시점의 타임스탬프
    public let creationTimestamp: Date
    
    /// 청크의 품질 지표 (0.0 ~ 1.0)
    public let qualityScore: Double
    
    // MARK: - Initialization
    
    /// 안전한 초기화를 위한 빌더 패턴 지원
    public init(
        id: ChunkID,
        documentId: DocumentID,
        content: String,
        tokenCount: TokenCount,
        breadcrumb: Breadcrumb,
        sourceNodeIDs: Set<NodeID>,
        documentMetadata: DocumentMetadata,
        qualityScore: Double = 1.0
    ) {
        self.id = id
        self.documentId = documentId
        self.content = content
        self.tokenCount = tokenCount
        self.breadcrumb = breadcrumb
        self.sourceNodeIDs = sourceNodeIDs
        self.documentMetadata = documentMetadata
        self.creationTimestamp = Date()
        self.qualityScore = max(0.0, min(1.0, qualityScore))
    }
    
    // MARK: - Computed Properties
    
    /// 청크의 예상 임베딩 차원 수 (모델별로 다를 수 있음)
    public var estimatedEmbeddingDimensions: Int {
        // 일반적인 텍스트 임베딩 모델 기준 추정
        min(tokenCount.value * 4, 1536)
    }
    
    /// 청크가 비어있는지 여부
    public var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 청크의 텍스트 밀도 (문자 수 / 토큰 수)
    public var textDensity: Double {
        guard tokenCount.value > 0 else { return 0.0 }
        return Double(content.count) / Double(tokenCount.value)
    }
}

// MARK: - Chunk Identifiable Conformance

extension Chunk: Identifiable {
    /// Identifiable 프로토콜을 위한 id 프로퍼티
    public var identifier: ChunkID { id }
}

// MARK: - Chunk Hashable Conformance

extension Chunk: Hashable {
    public static func == (lhs: Chunk, rhs: Chunk) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Chunk Codable Conformance

extension Chunk: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, documentId, content, tokenCount, breadcrumb
        case sourceNodeIDs, documentMetadata, creationTimestamp, qualityScore
    }
}

// MARK: - Type-Safe Identifiers

/// 청크의 고유 식별자를 위한 타입 안전 래퍼
@frozen
public struct ChunkID: Hashable, Codable, @unchecked Sendable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    /// 결정론적 청크 ID 생성
    public static func generate(documentId: DocumentID, index: Int) -> ChunkID {
        ChunkID("\(documentId.value)_chunk_\(index)")
    }
    
    /// 해시 기반 청크 ID 생성 (내용 기반)
    public static func generateContentBased(documentId: DocumentID, content: String) -> ChunkID {
        let combined = documentId.value + content
        let hash = SHA256.hash(data: Data(combined.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return ChunkID("\(documentId.value)_chunk_\(String(hashString.prefix(8)))")
    }
}

/// 문서의 고유 식별자를 위한 타입 안전 래퍼
@frozen
public struct DocumentID: Hashable, Codable, @unchecked Sendable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

/// 노드의 고유 식별자를 위한 타입 안전 래퍼
@frozen
public struct NodeID: Hashable, Codable, @unchecked Sendable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

/// 토큰 수를 위한 타입 안전 래퍼
@frozen
public struct TokenCount: Hashable, Codable, @unchecked Sendable {
    public let value: Int
    
    public init(_ value: Int) {
        self.value = max(0, value)
    }
    
    /// 토큰 수 덧셈
    public static func + (lhs: TokenCount, rhs: TokenCount) -> TokenCount {
        TokenCount(lhs.value + rhs.value)
    }
    
    /// 토큰 수 비교
    public static func > (lhs: TokenCount, rhs: TokenCount) -> Bool {
        lhs.value > rhs.value
    }
}

/// 브레드크럼을 위한 타입 안전 래퍼
@frozen
public struct Breadcrumb: Hashable, Codable, @unchecked Sendable {
    public let components: [String]
    
    public init(_ components: [String]) {
        self.components = components.filter { !$0.isEmpty }
    }
    
    public init(_ path: String, separator: String = " > ") {
        self.components = path.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// 브레드크럼 경로 문자열 반환
    public var path: String {
        components.joined(separator: " > ")
    }
    
    /// 브레드크럼 깊이
    public var depth: Int {
        components.count
    }
    
    /// 새로운 컴포넌트 추가
    public func appending(_ component: String) -> Breadcrumb {
        Breadcrumb(components + [component])
    }
}



extension ChunkID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension DocumentID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension NodeID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension TokenCount: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

// MARK: - Validation Extensions

extension Chunk {
    /// 청크의 유효성 검증
    public func validate() throws {
        guard !isEmpty else {
            throw ChunkValidationError.emptyContent
        }
        
        guard tokenCount.value > 0 else {
            throw ChunkValidationError.invalidTokenCount
        }
        
        guard qualityScore >= 0.0 && qualityScore <= 1.0 else {
            throw ChunkValidationError.invalidQualityScore
        }
        
        guard documentMetadata.isValid else {
            throw ChunkValidationError.invalidMetadata
        }
    }
}

/// 청크 유효성 검증 오류
public enum ChunkValidationError: Error, LocalizedError {
    case emptyContent
    case invalidTokenCount
    case invalidQualityScore
    case invalidMetadata
    
    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "청크 내용이 비어있습니다"
        case .invalidTokenCount:
            return "토큰 수가 유효하지 않습니다"
        case .invalidQualityScore:
            return "품질 점수가 유효하지 않습니다 (0.0-1.0 범위)"
        case .invalidMetadata:
            return "문서 메타데이터가 유효하지 않습니다"
        }
    }
}
