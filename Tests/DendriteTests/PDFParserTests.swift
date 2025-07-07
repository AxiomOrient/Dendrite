
// Tests/DendriteTests/PDFParserTests.swift

import Testing
import Foundation
import PDFKit
import CoreGraphics
@testable import Dendrite

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Mock Dependencies

private struct MockMetadataExtractor: PDFMetadataExtracting {
    func extract(from document: PDFDocument, processingTime: TimeInterval) -> DocumentMetadata {
        var metadata = DocumentMetadata()
        metadata.sourceDetails = .pdf(.init(totalPages: document.pageCount))
        return metadata
    }
}

private struct MockImageRenderer: PDFImageRendering {
    func render(page: PDFPage) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw TestError.mockingFailed("CGContext 생성에 실패했습니다.")
        }
        
        guard let image = context.makeImage() else {
            throw TestError.mockingFailed("CGImage 생성에 실패했습니다.")
        }
        return image
    }
}

private actor MockOCRService: VisionOCRServing {
    private(set) var performOCRCalled = false
    var ocrResultToReturn: OCRResult = .init(text: "Mocked OCR Text", confidence: 0.99)
    
    func performOCR(on cgImage: CGImage) async throws -> OCRResult {
        performOCRCalled = true
        return ocrResultToReturn
    }
}

// MARK: - PDFParser Unit Tests

@Suite("PDFParser Unit Tests", .tags(.unit, .fast))
final class PDFParserTests {

    /// **의도:** PDF 페이지의 네이티브 텍스트 길이가 임계값보다 길 때, OCR을 실행하지 않고 네이티브 텍스트를 사용하는지 검증합니다.
    @Test("OCR 조건: 텍스트가 임계값보다 길면 OCR 미실행")
    func testOCRLogic_whenTextIsLongerThanThreshold_doesNotPerformOCR() async throws {
        // Arrange
        let nativeText = "This native text is long enough to pass the threshold."
        let pdfData = try createTestPDFData(with: nativeText)
        
        let config = PDFParserConfiguration(textThreshold: 20)
        let mockOCRService = MockOCRService()
        let dependencies = PDFParser.Dependencies(
            metadataExtractor: MockMetadataExtractor(),
            imageRenderer: MockImageRenderer(),
            ocrService: mockOCRService
        )
        let parser = PDFParser(configuration: config, dependencies: dependencies)
        
        // Act
        let document = try await parser.parse(data: pdfData, type: .pdf)
        
        // Print for verification
        print("--- [Test: OCR Not Performed] ---")
        print("Parsed Content: \(document.content.prefix(50))...")
        print("Parsed Metadata: \(document.metadata)")
        print("---------------------------------")
        
        // Assert
        #expect(document.content.contains(nativeText))
        #expect(await mockOCRService.performOCRCalled == false)
        
        let pdfMeta = try #require(document.metadata.sourceDetails?.pdfMetadata)
        #expect(pdfMeta.ocrProcessedPages == 0)
    }
    
    /// **의도:** PDF 페이지의 네이티브 텍스트 길이가 임계값보다 짧을 때, OCR을 실행하여 텍스트를 추출하는지 검증합니다.
    @Test("OCR 조건: 텍스트가 임계값보다 짧으면 OCR 실행")
    func testOCRLogic_whenTextIsShorterThanThreshold_performsOCR() async throws {
        // Arrange
        let nativeText = "Short text."
        let pdfData = try createTestPDFData(with: nativeText)
        
        let config = PDFParserConfiguration(textThreshold: 20)
        let mockOCRService = MockOCRService()
        let dependencies = PDFParser.Dependencies(
            metadataExtractor: MockMetadataExtractor(),
            imageRenderer: MockImageRenderer(),
            ocrService: mockOCRService
        )
        let parser = PDFParser(configuration: config, dependencies: dependencies)
        
        // Act
        let document = try await parser.parse(data: pdfData, type: .pdf)
        
        // Print for verification
        print("--- [Test: OCR Performed] ---")
        print("Parsed Content: \(document.content)")
        print("Parsed Metadata: \(document.metadata)")
        print("-----------------------------")
        
        // Assert
        #expect(document.content.contains("Mocked OCR Text"))
        #expect(await mockOCRService.performOCRCalled == true)

        let pdfMeta = try #require(document.metadata.sourceDetails?.pdfMetadata)
        #expect(pdfMeta.ocrProcessedPages == 1)
    }
}

// MARK: - Test Helpers

private extension PDFParserTests {
    /// Core Graphics를 사용하여 텍스트가 포함된 테스트용 PDF 데이터를 생성합니다.
    func createTestPDFData(with text: String) throws -> Data {
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 300, height: 100)
        
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw TestError.mockingFailed("PDF CGContext 생성에 실패했습니다.")
        }
        
        context.beginPDFPage(nil)
        
        #if canImport(AppKit)
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext
        #elseif canImport(UIKit)
        UIGraphicsPushContext(context)
        #endif

        let attributedString = NSAttributedString(string: text)
        attributedString.draw(in: mediaBox)
        
        #if canImport(UIKit)
        UIGraphicsPopContext()
        #elseif canImport(AppKit)
        NSGraphicsContext.current = nil
        #endif
        
        context.endPDFPage()
        context.closePDF()
        
        return pdfData as Data
    }
}

private extension DocumentMetadata.SourceSpecificMetadata {
    var pdfMetadata: DocumentMetadata.PDFMetadata? {
        guard case .pdf(let meta) = self else { return nil }
        return meta
    }
}

private enum TestError: Error, CustomStringConvertible {
    case mockingFailed(String)
    var description: String {
        switch self {
        case .mockingFailed(let reason):
            return "테스트 모의 객체 설정 실패: \(reason)"
        }
    }
}

