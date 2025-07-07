// Sources/Dendrite/Core/PDFImageRendering.swift

import Foundation
import PDFKit
import CoreGraphics

/// PDF 페이지를 이미지로 렌더링하는 서비스의 인터페이스입니다.
public protocol PDFImageRendering: Sendable {
    
    /// PDFPage를 CGImage로 렌더링합니다.
    /// - Parameter page: 렌더링할 `PDFPage`
    /// - Returns: 렌더링된 `CGImage`
    /// - Throws: 렌더링 과정에서 발생한 에러
    func render(page: PDFPage) throws -> CGImage
}
