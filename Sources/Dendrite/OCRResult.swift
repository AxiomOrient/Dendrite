// Sources/Dendrite/OCRResult.swift

import Foundation

/// OCR(광학 문자 인식) 결과를 담는 불변 구조체입니다.
///
/// `Sendable`을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct OCRResult: Sendable {
    /// 이미지에서 인식된 전체 텍스트입니다.
    public let text: String
    
    /// 인식된 텍스트의 평균 신뢰도 점수입니다.
    ///
    /// 이 값은 0.0(신뢰도 낮음)에서 1.0(신뢰도 높음) 사이의 부동소수점 수입니다.
    public let confidence: Float
}
