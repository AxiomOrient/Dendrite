// Sources/Dendrite/DendriteConfig.swift

import Foundation
import UniformTypeIdentifiers
import Vision

/// Dendrite 라이브러리의 동작을 구성하는 설정 객체입니다.
///
/// 이 설정을 통해 사용할 파서를 직접 주입하거나, 각 파서의 세부 동작을 제어할 수 있습니다.
/// Sendable을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct DendriteConfig: Sendable {
    
    /// 파싱에 사용될 `ParserProtocol`을 준수하는 파서의 배열입니다.
    ///
    /// 이 배열의 순서가 파서의 우선순위가 됩니다.
    let parsers: [any ParserProtocol]

    // MARK: - Initializers

    /// Dendrite 라이브러리의 설정을 초기화합니다.
    /// - Parameters:
    ///   - customParsers: 기본 파서 세트를 대체하거나 추가할 커스텀 파서 배열입니다. `nil`인 경우 기본 세트가 사용됩니다.
    ///   - pdfTextThreshold: PDF 파싱 시, 네이티브 텍스트 길이가 이 값 미만일 경우 OCR을 실행합니다.
    ///   - ocrLanguages: Vision OCR에 사용할 언어 코드 배열입니다. (예: ["ko-KR", "en-US"])
    ///   - ocrAccuracy: Vision OCR의 정확도 수준입니다.
    public init(
        customParsers: [any ParserProtocol]? = nil,
        pdfTextThreshold: Int = 10,
        ocrLanguages: [String] = ["ko-KR", "en-US"],
        ocrAccuracy: VNRequestTextRecognitionLevel = .accurate
    ) {
        if let customParsers = customParsers {
            self.parsers = customParsers
        } else {
            // --- FIX: 이제 PDFParser() 호출이 @MainActor에 격리되지 않아 안전합니다. ---
            self.parsers = [
                PDFParser(
                    textThreshold: pdfTextThreshold,
                    ocrLanguages: ocrLanguages,
                    ocrAccuracy: ocrAccuracy
                ),
                MarkdownParser(),
                RichTextParser(),
                PlainTextParser()
            ]
        }
    }
    
    /// Dendrite 라이브러리의 기본 설정입니다.
    // --- FIX: DendriteConfig가 Sendable이 되었으므로 static 프로퍼티가 안전합니다. ---
    public static let `default` = DendriteConfig()
}
