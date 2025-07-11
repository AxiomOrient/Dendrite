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
    
    public func parse(data: Data, type: UTType, metadataBuilder: DocumentMetadataBuilder) async throws -> (nodes: [SemanticNode], metadata: DocumentMetadata) {
        guard let textContent = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        // 작업 취소 확인
        try Task.checkCancellation()
        
        // 전체 텍스트를 단일 문단 노드로 변환
        let nodes: [SemanticNode] = [.paragraph(children: [.text(textContent)])]
        
        // 소스 특화 메타데이터 생성 및 추가
        let plainTextMetadata = SourceSpecificMetadata.PlainTextMetadata(
            encoding: "UTF-8",
            lineEnding: .lf, // 기본값, 필요 시 감지 로직 추가 가능
            lineCount: textContent.components(separatedBy: .newlines).count
        )
        metadataBuilder.sourceDetails(.plainText(plainTextMetadata))
        
        return (
            nodes: nodes,
            metadata: metadataBuilder.build()
        )
    }
}
