// Sources/Dendrite/Services/PDFImageRenderer.swift

import Foundation
import PDFKit
import CoreGraphics

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

/// PDF 페이지를 이미지로 렌더링하는 서비스의 구체적인 구현체입니다.
struct PDFImageRenderer: PDFImageRendering {
    func render(page: PDFPage) throws -> CGImage {
        let pageRect = page.bounds(for: .mediaBox)
        
        #if canImport(UIKit)
        return try renderWithUIKit(page: page, pageRect: pageRect)
        #elseif canImport(AppKit)
        return try renderWithAppKit(page: page, pageRect: pageRect)
        #endif
    }
    
    #if canImport(UIKit)
    private func renderWithUIKit(page: PDFPage, pageRect: CGRect) throws -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            PlatformColor.white.setFill()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        guard let cgImage = image.cgImage else {
            throw DendriteError.pdfImageRenderingFailure
        }
        return cgImage
    }
    #endif
    
    #if canImport(AppKit)
    private func renderWithAppKit(page: PDFPage, pageRect: CGRect) throws -> CGImage {
        let image = NSImage(size: pageRect.size, flipped: false) { rect in
            PlatformColor.white.drawSwatch(in: rect)
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.translateBy(x: 0, y: rect.height)
                context.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()
            }
            return true
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DendriteError.pdfImageRenderingFailure
        }
        return cgImage
    }
    #endif
}
