// Sources/Dendrite/DendriteConfig.swift

import Foundation
import UniformTypeIdentifiers
import Vision

/// `Dendrite` 라이브러리의 동작을 구성하는 설정 객체입니다.
///
/// 이 설정을 통해 사용할 파서를 직접 주입하거나, 각 파서의 세부 동작을 제어할 수 있습니다.
/// `Sendable`을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
///
/// ## 사용 예시
/// ```swift
/// // PDF의 텍스트 임계값을 100으로, OCR 언어를 영어로 설정
/// let pdfConfig = PDFParserConfiguration(
///     textThreshold: 100,
///     ocrConfiguration: .init(languages: ["en-US"])
/// )
///
/// // 커스텀 설정을 포함하는 DendriteConfig 생성
/// let customConfig = DendriteConfig(pdfConfiguration: pdfConfig)
///
/// // 파싱 시 커스텀 설정 적용
/// let document = try await Dendrite.parse(from: url, config: customConfig)
/// ```
public struct DendriteConfig: Sendable {
    
    /// 파싱에 사용될 ``ParserProtocol``을 준수하는 파서의 배열입니다.
    ///
    /// - Important: 이 배열의 순서가 파서의 우선순위가 됩니다. `Dendrite`는 파일 타입을 처리할 파서를 찾을 때
    ///              이 배열의 앞에서부터 순서대로 `canParse(type:)` 메서드를 호출합니다.
    let parsers: [any ParserProtocol]

    // MARK: - Initializers

    /// `Dendrite` 라이브러리의 설정을 초기화합니다.
    ///
    /// - Parameters:
    ///   - customParsers: 기본 파서 세트를 대체하거나 추가할 커스텀 파서 배열입니다. 
    ///                    `nil`인 경우, 기본으로 제공되는 파서 세트가 사용됩니다. 
    ///                    기본 파서 목록은 `HTMLParser`, `PDFParser`, `MarkdownParser`, `RichTextParser`, `PlainTextParser`를 포함합니다.
    ///   - pdfConfiguration: PDF 파서(`PDFParser`)에 적용할 설정입니다. ``PDFParserConfiguration``을 참고하세요.
    public init(
        customParsers: [any ParserProtocol]? = nil,
        pdfConfiguration: PDFParserConfiguration = .init()
    ) {
        if let customParsers = customParsers {
            self.parsers = customParsers
        } else {
            // PDFParser 생성 방식을 정적 팩토리 메서드 호출로 변경합니다.
            self.parsers = [
                HTMLParser(),
                PDFParser.makeDefault(configuration: pdfConfiguration),
                MarkdownParser(),
                RichTextParser(),
                PlainTextParser()
            ]
        }
    }
    
    /// `Dendrite` 라이브러리의 기본 설정입니다.
    ///
    /// 모든 파서의 기본값이 적용된 설정 객체입니다.
    public static let `default` = DendriteConfig()
}
