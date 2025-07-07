// Sources/Dendrite/Core/VisionOCRServing.swift

import Foundation
import CoreGraphics

/// Vision 프레임워크를 사용한 OCR 서비스의 인터페이스입니다.
public protocol VisionOCRServing: Sendable {
    
    /// 주어진 이미지에서 텍스트를 인식합니다.
    /// - Parameter cgImage: OCR을 수행할 `CGImage`
    /// - Returns: 인식된 텍스트와 신뢰도를 포함하는 `OCRResult`
    /// - Throws: OCR 수행 중 발생한 에러
    func performOCR(on cgImage: CGImage) async throws -> OCRResult
}
