import Foundation

/// 문서에서 추출된 메타데이터를 타입-안전(Type-Safe) 방식으로 담는 구조체입니다.
///
/// 각 파서는 자신의 책임에 맞는 메타데이터를 생성하여 이 구조체를 채웁니다.
/// 공통 메타데이터와 함께, ``sourceDetails``를 통해 파일 형식별 고유 정보를 제공합니다.
public struct DocumentMetadata: Sendable {

    // MARK: - Common Metadata
    
    /// 문서의 제목입니다.
    public var title: String?
    /// 문서의 저자입니다.
    public var author: String?
    /// 문서의 생성일입니다.
    public var creationDate: Date?
    /// 문서의 마지막 수정일입니다.
    public var modificationDate: Date?
    /// 문서 내에 포함된 하이퍼링크의 목록입니다.
    public var links: [String]?

    /// 파싱 작업에 소요된 시간(초)입니다.
    public var processingTime: TimeInterval?

    /// 파일 형식에 따른 고유한 메타데이터입니다.
    ///
    /// ``SourceSpecificMetadata`` 열거형을 통해 각 파일 형식에 맞는
    /// 구체적인 메타데이터에 접근할 수 있습니다.
    ///
    /// ```swift
    /// if case .pdf(let pdfMeta) = document.metadata.sourceDetails {
    ///     print("PDF 페이지 수: \(pdfMeta.totalPages)")
    /// }
    /// ```
    public var sourceDetails: SourceSpecificMetadata?

    // MARK: - Source-Specific Metadata Enum

    /// 파일 형식별 고유 메타데이터를 타입-안전하게 저장하는 열거형입니다.
    public enum SourceSpecificMetadata: Sendable {
        /// PDF 파일의 고유 메타데이터입니다.
        case pdf(PDFMetadata)
        /// Markdown 파일의 고유 메타데이터입니다.
        case markdown(MarkdownMetadata)
        /// HTML 파일의 고유 메타데이터입니다.
        case html(HTMLMetadata)
    }

    // MARK: - Nested Metadata Structs

    /// PDF 파일의 고유 메타데이터를 담는 구조체입니다.
    public struct PDFMetadata: Sendable {
        /// PDF의 총 페이지 수입니다.
        public var totalPages: Int
        /// OCR(광학 문자 인식)이 수행된 페이지의 수입니다.
        public var ocrProcessedPages: Int = 0
        /// PDF가 암호화되었는지 여부입니다.
        public var isEncrypted: Bool = false
    }

    /// Markdown 파일의 고유 메타데이터를 담는 구조체입니다.
    public struct MarkdownMetadata: Sendable {
        /// 문서의 헤더(H1, H2, ...)들로 구성된 개요(outline)입니다.
        public var outline: [String]?
    }
    
    /// HTML 파일의 고유 메타데이터를 담는 구조체입니다.
    public struct HTMLMetadata: Sendable {
        // 현재는 비어 있으며, 향후 HTML 고유의 메타데이터가 필요할 경우 여기에 추가됩니다.
    }

    /// 비어 있는 메타데이터 인스턴스를 생성합니다.
    public init() {}
}
