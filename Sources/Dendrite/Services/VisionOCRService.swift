// Sources/Dendrite/Services/VisionOCRService.swift

import Foundation
import Vision
import CoreGraphics

/// Vision 프레임워크를 사용한 OCR 서비스의 구체적인 구현체입니다.
public struct VisionOCRService: VisionOCRServing {
    private let configuration: OCRConfiguration
    
    public init(configuration: OCRConfiguration) {
        self.configuration = configuration
    }
    
    public func performOCR(on cgImage: CGImage) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { visionRequest, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let ocrResult = Self.processVisionResults(visionRequest.results)
                    continuation.resume(returning: ocrResult)
                }
            }
            
            Self.configureRequest(request, with: configuration)
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private static func configureRequest(_ request: VNRecognizeTextRequest, with configuration: OCRConfiguration) {
        request.recognitionLevel = configuration.recognitionLevel
        request.recognitionLanguages = configuration.languages
        request.usesLanguageCorrection = true
    }
    
    private static func processVisionResults(_ results: [Any]?) -> OCRResult {
        let observations = results as? [VNRecognizedTextObservation] ?? []
        let topCandidates = observations.compactMap { $0.topCandidates(1).first }
        
        let text = topCandidates.map(\.string).joined(separator: "\n")
        let averageConfidence = Self.calculateAverageConfidence(from: topCandidates)
        
        return OCRResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: averageConfidence
        )
    }
    
    private static func calculateAverageConfidence(from candidates: [VNRecognizedText]) -> Float {
        guard !candidates.isEmpty else { return 0 }
        
        let confidenceSum = candidates.reduce(0) { $0 + $1.confidence }
        return confidenceSum / Float(candidates.count)
    }
}
