// Sources/Dendrite/Parsers/PDFParser.swift

import Foundation
import UniformTypeIdentifiers
import PDFKit
import Vision
import CoreGraphics

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#endif

/// PDF 문서를 파싱하는 지능형 하이브리드 파서입니다.
///
/// 네이티브 텍스트 추출을 우선 시도하고, 텍스트가 부족할 경우 Vision 프레임워크를 이용한 OCR을 수행합니다.
/// 이 클래스는 Sendable을 준수하여 동시성 환경에서 안전하게 사용될 수 있습니다.
final class PDFParser: ParserProtocol {
    
    // MARK: - Properties

    public let supportedTypes: [UTType] = [.pdf]
    
    private let textThreshold: Int
    private let ocrLanguages: [String]
    private let ocrAccuracy: VNRequestTextRecognitionLevel

    // MARK: - Initialization
    
    /// PDFParser를 초기화합니다.
    /// - Parameters:
    ///   - textThreshold: OCR 실행 기준이 되는 최소 텍스트 길이입니다.
    ///   - ocrLanguages: OCR에 사용할 언어 코드 배열입니다.
    ///   - ocrAccuracy: OCR의 정확도 수준입니다.
    init(
        textThreshold: Int,
        ocrLanguages: [String],
        ocrAccuracy: VNRequestTextRecognitionLevel
    ) {
        self.textThreshold = textThreshold
        self.ocrLanguages = ocrLanguages
        self.ocrAccuracy = ocrAccuracy
    }
    
    // MARK: - ParserProtocol Implementation
    
    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        
        // defer를 사용하여 함수가 종료될 때 항상 임시 파일이 삭제되도록 보장합니다.
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        do {
            try data.write(to: tempURL)
            // 작업이 취소되었는지 확인합니다.
            try Task.checkCancellation()
            
            let result = try await self.parseDocument(at: tempURL)
            
            var metadata = DocumentMetadata()
            metadata.totalPages = result.totalPages
            metadata.processingTime = result.processingTime
            metadata.ocrProcessedPages = result.ocrProcessedPages
            
            return ParsedDocument(content: result.fullText, metadata: metadata)
            
        } catch {
            // 오류 발생 시, 구체적인 파서 이름과 함께 에러를 래핑하여 상위로 전파합니다.
            throw DendriteError.parsingFailed(parserName: "PDFParser", underlyingError: error)
        }
    }
    
    // MARK: - Private Core Logic
    
    /// PDF 문서 전체를 파싱합니다.
    private func parseDocument(at url: URL) async throws -> PDFParseResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let document = PDFDocument(url: url) else {
            throw DendriteError.pdfDocumentLoadFailure
        }
        
        let totalPages = document.pageCount
        var parsedPages: [ParsedPage] = []
        
        // 각 페이지를 순차적으로 처리합니다.
        for pageIndex in 0..<totalPages {
            // 매 페이지 처리 전 작업 취소 여부를 확인합니다.
            try Task.checkCancellation()
            let parsedPage = try await processPage(document: document, pageIndex: pageIndex)
            parsedPages.append(parsedPage)
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return PDFParseResult(
            totalPages: totalPages,
            pages: parsedPages,
            processingTime: processingTime
        )
    }
    
    /// 개별 페이지를 처리하여 네이티브 텍스트 추출 또는 OCR을 수행합니다.
    private func processPage(document: PDFDocument, pageIndex: Int) async throws -> ParsedPage {
        guard let page = document.page(at: pageIndex) else {
            throw DendriteError.pdfPageNotFound(pageNumber: pageIndex + 1)
        }
        
        let pageNumber = pageIndex + 1
        let nativeText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // 텍스트가 임계값보다 적으면 OCR을 실행하는 전략을 선택합니다.
        if nativeText.count < textThreshold {
            return try await performOCR(on: page, pageNumber: pageNumber)
        } else {
            return ParsedPage(
                pageNumber: pageNumber,
                text: nativeText,
                extractionMethod: .nativePDF,
                confidence: nil
            )
        }
    }
    
    // MARK: - OCR Helper Methods

    /// Vision 프레임워크를 사용하여 페이지에서 OCR을 수행합니다.
    private func performOCR(on page: PDFPage, pageNumber: Int) async throws -> ParsedPage {
        // OCR 수행 전 작업 취소를 확인합니다.
        try Task.checkCancellation()
        
        let cgImage = try renderPageAsImage(page: page)
        
        let ocrResult = try await performVisionRequest(on: cgImage)
        
        return ParsedPage(
            pageNumber: pageNumber,
            text: ocrResult.text,
            extractionMethod: .ocr,
            confidence: ocrResult.confidence
        )
    }
    
    /// `VNRecognizeTextRequest`를 생성하고 실행하여 OCR 결과를 반환합니다.
    private func performVisionRequest(on cgImage: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    // 텍스트를 찾지 못한 경우, 오류가 아닌 빈 결과로 처리합니다.
                    continuation.resume(returning: OCRResult(text: "", confidence: 0))
                    return
                }
                
                let topCandidates = observations.compactMap { $0.topCandidates(1).first }
                let text = topCandidates.map(\.string).joined(separator: "\n")
                let confidenceSum = topCandidates.reduce(0) { $0 + $1.confidence }
                let averageConfidence = topCandidates.isEmpty ? 0 : confidenceSum / Float(topCandidates.count)

                let result = OCRResult(
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: averageConfidence
                )
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = self.ocrAccuracy
            request.recognitionLanguages = self.ocrLanguages
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// PDF 페이지를 `CGImage`로 렌더링합니다.
    private func renderPageAsImage(page: PDFPage) throws -> CGImage {
        let pageRect = page.bounds(for: .mediaBox)
        
        #if canImport(UIKit)
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
        
        #elseif canImport(AppKit)
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
        #endif
    }
}

// MARK: - Supporting Types
private extension PDFParser {
    
    /// 페이지별 추출된 텍스트와 메타데이터를 담는 내부용 구조체
    struct ParsedPage: Equatable {
        let pageNumber: Int
        let text: String
        let extractionMethod: ExtractionMethod
        let confidence: Float?
        
        enum ExtractionMethod: Equatable {
            case nativePDF
            case ocr
        }
    }

    /// PDF 파싱 중간 결과를 담는 내부용 구조체
    struct PDFParseResult: Equatable {
        let totalPages: Int
        let pages: [ParsedPage]
        let processingTime: TimeInterval
        
        var fullText: String {
            pages.map(\.text).joined(separator: "\n\n")
        }
        
        var ocrProcessedPages: Int {
            pages.filter { $0.extractionMethod == .ocr }.count
        }
    }
    
    /// OCR 결과를 담는 내부용 구조체
    struct OCRResult {
        let text: String
        let confidence: Float
    }
}
