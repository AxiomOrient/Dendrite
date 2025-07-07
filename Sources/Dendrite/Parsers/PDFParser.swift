// Sources/Dendrite/Parsers/PDFParser.swift

import Foundation
import UniformTypeIdentifiers
import PDFKit
import Vision
import CoreGraphics

/// PDF 문서를 파싱하는 지능형 하이브리드 파서입니다.
///
/// 네이티브 텍스트 추출을 우선 시도하고, 텍스트가 부족할 경우 Vision 프레임워크를 이용한 OCR을 수행합니다.
/// Swift의 동시성 모델을 활용하여 안전하고 효율적인 처리를 제공합니다.
actor PDFParser: ParserProtocol {

    // MARK: - Dependencies

    /// PDFParser가 의존하는 서비스들을 그룹화한 타입입니다.
    /// 이 구조체를 사용함으로써 의존성 관리가 명확해지고, 테스트 시 모의 객체(Mock) 주입이 용이해집니다.
    struct Dependencies {
        let metadataExtractor: any PDFMetadataExtracting
        let imageRenderer: any PDFImageRendering
        let ocrService: any VisionOCRServing

        /// 프로덕션 환경에서 사용될 기본 의존성 세트입니다.
        static func makeDefault(with config: PDFParserConfiguration) -> Dependencies {
            Dependencies(
                metadataExtractor: PDFMetadataExtractor(),
                imageRenderer: PDFImageRenderer(),
                ocrService: VisionOCRService(configuration: config.ocrConfiguration)
            )
        }
    }

    // MARK: - Properties
    
    public let supportedTypes: [UTType] = [.pdf]
    
    private let configuration: PDFParserConfiguration
    private let dependencies: Dependencies
    
    // MARK: - Initialization
    
    /// 지정된 설정과 의존성을 사용하여 PDFParser 인스턴스를 생성합니다.
    /// 테스트 환경에서는 이 초기화 메서드를 통해 모의(Mock) 의존성을 주입할 수 있습니다.
    /// - Parameters:
    ///   - configuration: 파서의 동작을 제어하는 설정 객체
    ///   - dependencies: 파서가 사용하는 외부 서비스들의 묶음
    init(configuration: PDFParserConfiguration, dependencies: Dependencies) {
        self.configuration = configuration
        self.dependencies = dependencies
    }

    /// 기본 의존성을 사용하여 PDFParser 인스턴스를 생성하는 정적 팩토리 메서드입니다.
    /// 일반적인 사용 시에는 이 메서드를 통해 파서를 생성하는 것을 권장합니다.
    /// - Parameter configuration: 파서의 동작을 제어하는 설정 객체
    /// - Returns: 새로 생성된 PDFParser 인스턴스
    static func makeDefault(configuration: PDFParserConfiguration = .init()) -> PDFParser {
        let defaultDependencies = Dependencies.makeDefault(with: configuration)
        return PDFParser(configuration: configuration, dependencies: defaultDependencies)
    }
    
    // MARK: - ParserProtocol Implementation
    
    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        try Task.checkCancellation()
        
        guard let document = PDFDocument(data: data) else {
            throw DendriteError.pdfDocumentLoadFailure
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let (fullText, ocrPageCount) = try await extractText(from: document)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // 의존성을 통해 메타데이터 추출기 사용
            var metadata = dependencies.metadataExtractor.extract(from: document, processingTime: processingTime)
            
            if case .pdf(var pdfMeta) = metadata.sourceDetails {
                pdfMeta.ocrProcessedPages = ocrPageCount
                metadata.sourceDetails = .pdf(pdfMeta)
            }
            
            return ParsedDocument(content: fullText, metadata: metadata)
            
        } catch {
            throw DendriteError.parsingFailed(parserName: "PDFParser", underlyingError: error)
        }
    }
    
    // MARK: - Private Methods
    
    private func extractText(from document: PDFDocument) async throws -> (fullText: String, ocrPageCount: Int) {
        var extractedTexts: [String] = []
        var ocrPageCount = 0
        
        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            
            guard let page = document.page(at: pageIndex) else {
                throw DendriteError.pdfPageNotFound(pageNumber: pageIndex + 1)
            }
            
            let (text, didOcr) = try await extractText(from: page)
            extractedTexts.append(text)
            if didOcr { ocrPageCount += 1 }
        }
        
        return (extractedTexts.joined(separator: "\n\n"), ocrPageCount)
    }
    
    private func extractText(from page: PDFPage) async throws -> (text: String, didOcr: Bool) {
        let nativeText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if shouldUseOCR(for: nativeText) {
            let ocrText = try await performOCRExtraction(on: page)
            return (ocrText, true)
        } else {
            return (nativeText, false)
        }
    }
    
    private func shouldUseOCR(for text: String) -> Bool {
        text.count < configuration.textThreshold
    }
    
    private func performOCRExtraction(on page: PDFPage) async throws -> String {
        try Task.checkCancellation()
        
        // 의존성을 통해 이미지 렌더러와 OCR 서비스 사용
        let cgImage = try dependencies.imageRenderer.render(page: page)
        let ocrResult = try await dependencies.ocrService.performOCR(on: cgImage)
        
        return ocrResult.text
    }
}
