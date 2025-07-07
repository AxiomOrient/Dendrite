// Sources/Dendrite/Services/PDFMetadataExtractor.swift

import Foundation
import PDFKit

/// PDF 문서에서 메타데이터를 추출하는 서비스의 구체적인 구현체입니다.
struct PDFMetadataExtractor: PDFMetadataExtracting { // 'PDFMetadataExtracting' 프로토콜 준수 명시
    
    // 'extract'로 함수 이름 변경하여 프로토콜 요구사항 준수
    func extract(from document: PDFDocument, processingTime: TimeInterval) -> DocumentMetadata {
        var metadata = DocumentMetadata()
        
        if let attributes = document.documentAttributes {
            metadata.title = attributes[PDFDocumentAttribute.titleAttribute] as? String
            metadata.author = attributes[PDFDocumentAttribute.authorAttribute] as? String
            metadata.creationDate = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date
            metadata.modificationDate = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date
        }
        
        metadata.processingTime = processingTime
        
        let pdfMeta = DocumentMetadata.PDFMetadata(
            totalPages: document.pageCount,
            ocrProcessedPages: 0, // 이 값은 PDFParser에서 최종 설정됨
            isEncrypted: document.isEncrypted
        )
        metadata.sourceDetails = .pdf(pdfMeta)
        
        return metadata
    }
}
