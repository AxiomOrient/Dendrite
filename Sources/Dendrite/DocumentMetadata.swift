// Sources/Dendrite/DocumentMetadata.swift

import Foundation

/// 문서에서 추출된 메타데이터를 타입-안전(Type-Safe) 방식으로 담는 구조체입니다.
///
/// 모든 파서는 이 구조체를 사용하여 일관된 형식으로 메타데이터를 반환합니다.
/// Sendable을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct DocumentMetadata: Sendable {
    
    // MARK: - Common Metadata
    
    /// 문서의 제목입니다.
    public var title: String?
    
    /// 문서의 저자입니다.
    public var author: String?
    
    /// 문서의 생성일입니다.
    public var creationDate: Date?
    
    // MARK: - Structured Content
    
    /// 문서의 구조를 나타내는 개요(제목 목록 등)입니다.
    public var outline: [String]?
    
    /// 문서 내에 포함된 하이퍼링크의 배열입니다.
    public var links: [String]?
    
    // MARK: - PDF Specific Metadata
    
    /// PDF 문서의 총 페이지 수입니다.
    public var totalPages: Int?
    
    /// PDF 문서에서 OCR로 처리된 페이지 수입니다.
    public var ocrProcessedPages: Int?

    // MARK: - Processing Information
    
    /// 파싱 작업에 소요된 시간(초)입니다.
    public var processingTime: TimeInterval?
    
    // MARK: - Custom Metadata
    
    /// 위에 정의되지 않은 추가적인 메타데이터를 저장하기 위한 딕셔너리입니다.
    // --- FIX: [String: Any]를 [String: any Sendable]로 변경하여 Sendable 준수 ---
    public var custom: [String: any Sendable] = [:]

    /// 비어 있는 메타데이터 인스턴스를 생성합니다.
    public init() {}
}
