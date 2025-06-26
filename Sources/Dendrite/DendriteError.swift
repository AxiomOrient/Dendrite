// Sources/Dendrite/DendriteError.swift

import Foundation

/// Dendrite 라이브러리에서 발생할 수 있는 오류를 정의합니다.
public enum DendriteError: Error, LocalizedError {
    
    /// 파일 URL에 접근하거나 데이터를 읽는 데 실패했을 때 발생하는 오류입니다.
    /// - `url`: 접근에 실패한 파일의 URL입니다.
    /// - `underlyingError`: 파일 읽기 실패의 근본 원인이 된 시스템 에러입니다.
    case fileReadFailed(url: URL, underlyingError: Error)
    
    /// 지원하지 않는 파일 형식일 때 발생하는 오류입니다.
    /// - `fileExtension`: 지원하지 않는 파일의 확장자입니다.
    case unsupportedFileType(fileExtension: String)
    
    /// 파일 파싱 과정에서 실패했을 때 발생하는 오류입니다.
    /// - `parserName`: 파싱을 시도한 파서의 이름입니다.
    /// - `underlyingError`: 파싱 실패의 근본 원인이 된 에러입니다.
    case parsingFailed(parserName: String, underlyingError: Error)
    
    // MARK: - PDF Specific Errors (Can be nested under parsingFailed)
    
    /// PDF 문서를 로드하지 못했을 때 발생하는 오류입니다.
    case pdfDocumentLoadFailure
    
    /// PDF에서 특정 페이지를 찾지 못했을 때 발생하는 오류입니다.
    /// - `pageNumber`: 찾지 못한 페이지 번호입니다.
    case pdfPageNotFound(pageNumber: Int)
    
    /// PDF 페이지를 이미지로 렌더링하는 데 실패했을 때 발생하는 오류입니다.
    case pdfImageRenderingFailure
    
    // MARK: - Error Descriptions
    
    public var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let underlyingError):
            return "파일을 읽는 데 실패했습니다. URL: \(url.path). 원인: \(underlyingError.localizedDescription)"
        case .unsupportedFileType(let fileExtension):
            return "지원하지 않는 파일 형식입니다: .\(fileExtension)"
        case .parsingFailed(let parserName, let underlyingError):
            return "\(parserName) 파싱에 실패했습니다. 원인: \(underlyingError.localizedDescription)"
        case .pdfDocumentLoadFailure:
            return "PDF 문서 로드에 실패했습니다."
        case .pdfPageNotFound(let pageNumber):
            return "PDF에서 페이지 \(pageNumber)를 찾을 수 없습니다."
        case .pdfImageRenderingFailure:
            return "PDF 페이지를 이미지로 렌더링하는 데 실패했습니다."
        }
    }
}
