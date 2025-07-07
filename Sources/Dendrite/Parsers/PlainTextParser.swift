// Sources/Dendrite/Parsers/PlainTextParser.swift

import Foundation
import UniformTypeIdentifiers

/// 일반 텍스트(.txt) 파일을 처리하는 파서입니다.
///
/// 이 파서는 별도의 변환 없이 원본 텍스트를 그대로 콘텐츠로 사용합니다.
struct PlainTextParser: ParserProtocol {

    // MARK: - Properties

    public let supportedTypes: [UTType] = [.plainText]

    // MARK: - ParserProtocol Implementation

    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        guard let textContent = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        // 작업 취소 확인
        try Task.checkCancellation()
        
        return ParsedDocument(
            content: textContent,
            metadata: DocumentMetadata() // 빈 메타데이터 객체를 생성하여 반환합니다.
        )
    }
}
