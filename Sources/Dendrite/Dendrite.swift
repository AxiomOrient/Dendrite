// Sources/Dendrite/Dendrite.swift

import Foundation
import UniformTypeIdentifiers
import Vision
import CoreGraphics

/// 다양한 형식의 문서를 파싱하고 변환하는 라이브러리의 메인 API 네임스페이스입니다.
///
/// ## 개요
/// `Dendrite`는 파일 파싱, 형식 변환, 광학 문자 인식(OCR) 등 문서 처리와 관련된
/// 모든 고수준 API를 제공하는 정적 타입입니다.
/// 사용자는 이 타입을 통해 라이브러리의 모든 핵심 기능에 접근할 수 있습니다.
///
/// ### 주요 기능
/// - ``parse(from:config:)``: URL로부터 문서를 파싱합니다.
/// - ``parse(data:fileType:config:)``: 메모리의 `Data`로부터 문서를 파싱합니다.
/// - ``Converter``: 형식 변환 유틸리티를 제공합니다.
/// - ``OCR``: 이미지로부터 텍스트를 추출하는 OCR 기능을 제공합니다.
public enum Dendrite {
    
    // MARK: - Parsing API
    
    /// 지정된 URL의 파일을 파싱하여 텍스트와 메타데이터를 추출합니다.
    ///
    /// 이 메서드는 URL로부터 비동기적으로 데이터를 읽고, 파일 확장자에 맞는 파서를
    /// 동적으로 선택하여 파싱을 수행합니다.
    ///
    /// ```swift
    /// do {
    ///     let url = URL(string: "https://example.com/document.pdf")!
    ///     let document = try await Dendrite.parse(from: url)
    ///     print(document.content)
    /// } catch {
    ///     print("파싱 실패: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url: 파싱할 파일의 URL. 로컬 및 원격 URL을 모두 지원합니다.
    ///   - config: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `.default`입니다.
    /// - Returns: 파싱된 텍스트와 메타데이터를 담은 ``ParsedDocument``.
    /// - Throws: ``DendriteError`` 형식의 오류. 파일 읽기 실패, 지원하지 않는 파일 타입,
    ///           또는 내부 파싱 실패 시 발생할 수 있습니다.
    public static func parse(
        from url: URL,
        config: DendriteConfig = .default
    ) async throws -> ParsedDocument {
        
        // 1. 파일 확장자를 기반으로 UTType을 결정합니다.
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            throw DendriteError.unsupportedFileType(fileExtension: url.pathExtension)
        }
        
        // 2. URL로부터 데이터를 비동기적으로 읽습니다.
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DendriteError.fileReadFailed(url: url, underlyingError: error)
        }
        
        // 3. 데이터와 타입을 사용하여 파싱을 수행합니다.
        return try await parse(data: data, fileType: type, config: config)
    }
    
    /// 메모리에 있는 `Data`를 지정된 파일 타입으로 파싱합니다.
    ///
    /// 이 메서드는 라이브러리의 핵심 공개 API(Facade) 역할을 합니다.
    /// 내부적으로 `ParserFactory`를 통해 ``DendriteConfig``에 따라 적절한 파서를 선택하여
    /// 파싱 작업을 위임합니다.
    ///
    /// - Parameters:
    ///   - data: 파싱할 원본 데이터.
    ///   - fileType: 데이터의 파일 타입 (`UTType`).
    ///   - config: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `.default`입니다.
    /// - Returns: 파싱된 텍스트와 메타데이터를 담은 ``ParsedDocument``.
    /// - Throws: ``DendriteError`` 형식의 오류. 지원하지 않는 파일 타입 또는 내부 파싱 실패 시
    ///           발생할 수 있습니다.
    public static func parse(
        data: Data,
        fileType: UTType,
        config: DendriteConfig = .default
    ) async throws -> ParsedDocument {
        
        // 1. 팩토리에 설정 객체의 파서 목록을 전달하여 적절한 파서를 가져옵니다.
        guard let parser = ParserFactory.parser(for: fileType, availableParsers: config.parsers) else {
            throw DendriteError.unsupportedFileType(fileExtension: fileType.preferredFilenameExtension ?? "unknown")
        }
        
        // 2. 해당 파서로 파싱을 실행하고 결과를 반환합니다.
        do {
            return try await parser.parse(data: data, type: fileType)
        } catch let dendriteError as DendriteError {
            // 이미 DendriteError인 경우, 다시 래핑하지 않고 그대로 전파합니다.
            throw dendriteError
        } catch {
            // DendriteError가 아닌 다른 종류의 오류가 발생한 경우, 컨텍스트를 추가하여 래핑합니다.
            throw DendriteError.parsingFailed(parserName: String(describing: Swift.type(of: parser)), underlyingError: error)
        }
    }
    
    // MARK: - Conversion API
    
    /// 문서 형식 변환을 위한 유틸리티 네임스페이스입니다.
    public struct Converter {
        /// HTML 문자열을 Markdown 문자열로 변환합니다.
        ///
        /// 이 메서드는 내부적으로 HTML의 구조를 분석하여 의미론적으로 동등한
        /// Markdown 텍스트를 생성합니다.
        ///
        /// - Parameter html: 변환할 HTML 문자열.
        /// - Returns: 변환된 Markdown 문자열.
        /// - Throws: HTML 파싱 또는 변환 과정에서 오류가 발생할 수 있습니다.
        public static func htmlToMarkdown(from html: String) throws -> String {
            try MarkdownFromHTMLConverter().convert(html)
        }
    }
    
    // MARK: - OCR API
    
    /// OCR(광학 문자 인식) 기능을 위한 유틸리티 네임스페이스입니다.
    public enum OCR {
        /// 주어진 이미지(`CGImage`)에서 텍스트를 인식합니다.
        ///
        /// Vision 프레임워크를 기반으로 동작하며, 지정된 언어와 정확도 수준에 따라
        /// 이미지 내의 텍스트를 추출합니다.
        ///
        /// ```swift
        /// func performOCR(on image: CGImage) async {
        ///     let config = OCRConfiguration(languages: ["ko-KR", "en-US"])
        ///     do {
        ///         let result = try await Dendrite.OCR.perform(on: image, configuration: config)
        ///         print("인식된 텍스트: \(result.text)")
        ///         print("신뢰도: \(result.confidence)")
        ///     } catch {
        ///         print("OCR 실패: \(error)")
        ///     }
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - cgImage: OCR을 수행할 `CGImage` 객체.
        ///   - configuration: OCR 언어, 정확도 등을 포함하는 설정 객체.
        /// - Returns: 인식된 텍스트와 평균 신뢰도를 포함하는 ``OCRResult`` 객체.
        /// - Throws: Vision 프레임워크가 텍스트를 인식하는 과정에서 오류가 발생할 수 있습니다.
        public static func perform(
            on cgImage: CGImage,
            configuration: OCRConfiguration = .init()
        ) async throws -> OCRResult {
            let service = VisionOCRService(configuration: configuration)
            return try await service.performOCR(on: cgImage)
        }
    }
}
