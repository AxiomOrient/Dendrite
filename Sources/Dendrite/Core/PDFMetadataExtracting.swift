// Sources/Dendrite/Core/PDFMetadataExtracting.swift

import Foundation
import PDFKit

/// PDF 문서에서 메타데이터를 추출하는 서비스의 인터페이스입니다.
public protocol PDFMetadataExtracting: Sendable {
    
    /// PDFDocument에서 메타데이터를 추출합니다.
    /// - Parameters:
    ///   - document: 메타데이터를 추출할 `PDFDocument`
    ///   - processingTime: 파싱에 소요된 시간
    /// - Returns: 추출된 `DocumentMetadata`
    func extract(from document: PDFDocument, processingTime: TimeInterval) -> DocumentMetadata
}
