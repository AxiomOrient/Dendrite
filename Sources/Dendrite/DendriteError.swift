// Sources/Dendrite/DendriteError.swift

import Foundation

/// `Dendrite` 라이브러리에서 발생할 수 있는 오류를 정의합니다.
///
/// `LocalizedError`를 준수하여 사용자에게 보여줄 수 있는 오류 메시지를 제공합니다.
public enum DendriteError: Error, LocalizedError, Equatable {
    
    /// 파일 URL에 접근하거나 데이터를 읽는 데 실패했을 때 발생하는 오류입니다.
    /// - Parameters:
    ///   - url: 접근에 실패한 파일의 URL입니다.
    ///   - underlyingError: 파일 읽기 실패의 근본 원인이 된 시스템 에러입니다.
    case fileReadFailed(url: URL, underlyingError: Error)
    
    /// 지원하지 않는 파일 형식일 때 발생하는 오류입니다.
    /// - Parameters:
    ///   - fileExtension: 지원하지 않는 파일의 확장자입니다.
    case unsupportedFileType(fileExtension: String)
    
    /// 데이터 디코딩에 실패했을 때 발생하는 오류입니다.
    /// - Parameters:
    ///   - encoding: 디코딩에 사용된 인코딩 형식의 이름입니다. (예: "UTF-8")
    case decodingFailed(encoding: String)
    
    /// 파일 파싱 과정에서 실패했을 때 발생하는 오류입니다.
    /// - Parameters:
    ///   - parserName: 파싱을 시도한 파서의 이름입니다.
    ///   - underlyingError: 파싱 실패의 근본 원인이 된 에러입니다.
    case parsingFailed(parserName: String, underlyingError: Error)
    
    /// 의미론적 청킹 과정에서 실패했을 때 발생하는 오류입니다.
    /// - Parameters:
    ///   - underlyingError: 청킹 실패의 근본 원인이 된 에러입니다.
    case chunkingFailed(underlyingError: Error)
    
    // MARK: - Error Descriptions
    
    public var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let underlyingError):
            return "파일을 읽는 데 실패했습니다. URL: \(url.path). 원인: \(underlyingError.localizedDescription)"
        case .unsupportedFileType(let fileExtension):
            return "지원하지 않는 파일 형식입니다: .\(fileExtension)"
        case .decodingFailed(let encoding):
            return "\(encoding)으로 데이터를 디코딩하는 데 실패했습니다."
        case .parsingFailed(let parserName, let underlyingError):
            return "\(parserName) 파싱에 실패했습니다. 원인: \(underlyingError.localizedDescription)"
        case .chunkingFailed(let underlyingError):
            return "의미론적 청킹에 실패했습니다. 원인: \(underlyingError.localizedDescription)"
        }
    }
    
    public static func == (lhs: DendriteError, rhs: DendriteError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedFileType(let lExt), .unsupportedFileType(let rExt)):
            return lExt == rExt
        case (.fileReadFailed(let lURL, _), .fileReadFailed(let rURL, _)):
            return lURL == rURL
        case (.decodingFailed(let lEnc), .decodingFailed(let rEnc)):
            return lEnc == rEnc
        case (.parsingFailed(let lName, _), .parsingFailed(let rName, _)):
            return lName == rName
        case (.chunkingFailed, .chunkingFailed):
            return true // In a real scenario, you might compare underlying errors if they are Equatable.
        default:
            return false
        }
    }
}
