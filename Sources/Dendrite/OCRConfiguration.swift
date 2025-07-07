// Sources/Dendrite/OCRConfiguration.swift

import Foundation
import Vision

/// OCR(광학 문자 인식) 기능의 동작을 구성하는 설정 객체입니다.
///
/// `Sendable`을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct OCRConfiguration: Sendable {
    
    /// OCR에 사용할 언어의 배열입니다.
    ///
    /// Vision 프레임워크가 지원하는 언어 코드를 사용해야 합니다. (예: `["ko-KR", "en-US"]`)
    /// 언어 코드 목록은 Apple의 Vision 프레임워크 문서를 참고하세요.
    public let languages: [String]
    
    /// Vision OCR의 인식 수준을 결정합니다.
    ///
    /// - `.accurate`: 정확도를 우선합니다. (기본값)
    /// - `.fast`: 속도를 우선합니다.
    public let recognitionLevel: VNRequestTextRecognitionLevel
    
    /// OCR 설정을 초기화합니다.
    /// - Parameters:
    ///   - languages: 인식할 언어 코드의 배열. 기본값은 한국어와 영어를 포함하는 `["ko-KR", "en-US"]`입니다.
    ///   - recognitionLevel: 인식 수준(정확도 vs 속도). 기본값은 `.accurate`입니다.
    public init(
        languages: [String] = ["ko-KR", "en-US"],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) {
        self.languages = languages
        self.recognitionLevel = recognitionLevel
    }
}
