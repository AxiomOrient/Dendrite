// Sources/Dendrite/ParsedDocument.swift

import Foundation

/// 모든 파서가 반환하는 최종 결과물입니다.
///
/// 파싱된 텍스트 본문(`content`)과 타입-안전한 메타데이터(`metadata`)를 포함합니다.
/// Sendable을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct ParsedDocument: Sendable {
    
    /// 문서의 주요 텍스트 내용입니다.
    public let content: String

    /// 문서에서 추출한 구조화된 메타데이터입니다.
    public let metadata: DocumentMetadata
    
    /// ParsedDocument를 초기화합니다.
    /// - Parameters:
    ///   - content: 문서의 본문 텍스트입니다.
    ///   - metadata: 문서의 메타데이터입니다.
    public init(content: String, metadata: DocumentMetadata) {
        self.content = content
        self.metadata = metadata
    }
}
