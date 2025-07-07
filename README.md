# Dendrite: 지능형 문서 처리 프레임워크

![Dendrite Logo Placeholder](https://via.placeholder.com/150/0000FF/FFFFFF?text=Dendrite)

[![Swift Version](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/AxiomOrient/Dendrite?style=social)](https://github.com/AxiomOrient/Dendrite)

## 🚀 프로젝트 개요

**Dendrite**는 iOS 및 macOS 환경을 위해 Swift로 개발된 고성능 문서 처리 프레임워크입니다. 이 라이브러리는 RAG(검색 증강 생성) 시스템의 핵심 전처리 단계에 사용되는 것을 목표로 설계되었으며, 다양한 형식의 문서(로컬 파일, URL 등)로부터 텍스트 콘텐츠와 구조적인 메타데이터를 효율적으로 추출하는 데 특화되어 있습니다.

Dendrite는 복잡한 문서 파싱, 형식 변환, 그리고 OCR(광학 문자 인식) 과정을 단순하고 일관된 API 뒤로 추상화합니다. 이를 통해 개발자는 데이터 소스의 형식에 구애받지 않고 핵심 비즈니스 로직에 집중할 수 있으며, AI 기반 애플리케이션 개발의 생산성을 극대화할 수 있습니다.

## ✨ 핵심 기능

*   **다양한 문서 형식 파싱**: `HTML`, `PDF`, `Markdown`, 일반 텍스트(`TXT`), 리치 텍스트(`RTF`, `DOCX`*) 등 광범위한 문서 형식을 지원합니다.
    *   (*`DOCX`는 `AppKit` 프레임워크가 사용 가능한 macOS 환경에서만 지원됩니다.)
*   **지능형 하이브리드 PDF 처리**: PDF 문서 처리 시, 먼저 내장된 텍스트를 추출합니다. 만약 텍스트의 양이 설정된 임계값보다 적을 경우(이미지 기반 PDF로 간주), 자동으로 페이지를 이미지로 렌더링하여 Apple의 Vision 프레임워크를 이용한 OCR을 수행하는 하이브리드 방식을 사용합니다. 이는 텍스트 추출의 정확도와 효율성을 동시에 보장합니다.
*   **고급 광학 문자 인식 (OCR)**: Apple의 Vision 프레임워크를 기반으로 한 고정밀 OCR 기능을 제공합니다. 독립적인 API(`Dendrite.OCR.perform`)로도 사용 가능하며, 한국어와 영어를 포함한 다중 언어 인식 및 정확도 수준 설정이 가능합니다.
*   **구조적 메타데이터 추출**: 단순히 텍스트만 추출하는 것을 넘어, 문서의 제목, 저자, 생성일, 링크 목록 등 공통 메타데이터와 함께 PDF의 페이지 수, 암호화 여부, Markdown의 개요(Outline) 등 각 파일 형식에 특화된 풍부한 메타데이터를 함께 제공합니다.
*   **형식 변환 유틸리티**: 외부 API로 노출된 `Dendrite.Converter.htmlToMarkdown`을 통해 HTML 콘텐츠를 의미론적 구조를 최대한 보존하며 Markdown으로 변환할 수 있습니다.
*   **높은 수준의 설정 및 확장성**: `DendriteConfig` 객체를 통해 라이브러리의 동작을 세밀하게 제어할 수 있습니다. 또한, `ParserProtocol`을 준수하는 커스텀 파서를 구현하여 기본 파서 목록에 추가하거나 교체함으로써, 라이브러리가 지원하지 않는 새로운 파일 형식을 손쉽게 확장할 수 있습니다.

## 🏗️ 아키텍처 및 설계 원칙

Dendrite는 최신 Swift의 기능과 SOLID 원칙을 적극적으로 활용하여 유연하고, 테스트 가능하며, 확장하기 쉬운 구조로 설계되었습니다.

*   **Facade Pattern (퍼사드 패턴)**
    *   **구현**: `Dendrite.swift` 파일이 이 패턴의 핵심입니다.
    *   **설명**: 파싱, 변환, OCR 등 라이브러리의 복잡한 내부 서브시스템들을 간단하고 통일된 고수준 API(`Dendrite.parse`, `Dendrite.Converter`, `Dendrite.OCR`) 뒤로 숨깁니다. 이를 통해 라이브러리 사용자는 내부 구현의 복잡성을 알 필요 없이 손쉽게 핵심 기능에 접근할 수 있습니다.
*   **Dependency Injection (의존성 주입)**
    *   **구현**: `DendriteConfig` 및 `PDFParser.Dependencies` 구조체.
    *   **설명**: `DendriteConfig`를 통해 사용할 파서의 목록과 각 파서의 세부 설정을 외부에서 주입할 수 있습니다. 특히 `PDFParser`는 자신의 의존성(`PDFMetadataExtracting`, `PDFImageRendering`, `VisionOCRServing`)을 `Dependencies` 구조체로 그룹화하여 `init`을 통해 주입받습니다. 이는 `actor`의 초기화 제약을 해결할 뿐만 아니라, 각 컴포넌트의 책임을 명확히 분리하고 테스트 시 모의(Mock) 객체를 주입하기 매우 용이한 구조를 만듭니다.
*   **Strategy Pattern & Protocol-Oriented Design (전략 패턴 및 프로토콜 지향 설계)**
    *   **구현**: `ParserProtocol`, `TagConverting` 프로토콜.
    *   **설명**: 라이브러리의 핵심 기능은 프로토콜로 추상화됩니다. 각 파일 형식에 대한 처리 로직은 `ParserProtocol`을 채택한 구체적인 파서(`HTMLParser`, `PDFParser` 등)에 의해 '전략'처럼 구현됩니다. 마찬가지로 `MarkdownFromHTMLConverter`는 `TagConverting` 프로토콜을 사용하여 각 HTML 태그 처리 로직을 개별 전략 객체(`H1Converter`, `ParagraphConverter` 등)로 분리했습니다. 이 설계 덕분에 새로운 파일 형식이나 HTML 태그를 지원하기 위해 기존 코드를 수정할 필요 없이, 새로운 전략만 추가하면 됩니다. (OCP - 개방-폐쇄 원칙)
*   **Factory Pattern (팩토리 패턴)**
    *   **구현**: `ParserFactory.swift` 및 `PDFParser.makeDefault(configuration:)`.
    *   **설명**: `ParserFactory`는 런타임에 주어진 파일 타입(`UTType`)에 가장 적합한 파서(전략)를 동적으로 선택하여 반환합니다. `PDFParser.makeDefault`와 같은 정적 팩토리 메서드는 복잡한 의존성 생성 과정을 캡슐화하여, 사용자가 손쉽게 기본 설정으로 동작하는 인스턴스를 생성할 수 있도록 돕습니다.

## 📦 설치

Dendrite는 Swift Package Manager를 통해 프로젝트에 쉽게 추가할 수 있습니다.

1.  Xcode 프로젝트를 엽니다.
2.  **File > Add Packages...** 로 이동합니다.
3.  검색창에 GitHub 저장소 URL을 입력합니다: `https://github.com/AxiomOrient/Dendrite.git`
4.  **Up to Next Major Version** 규칙을 선택하고 **Add Package**를 클릭합니다.

## 🚀 사용 방법

Dendrite는 직관적이고 강력한 API를 제공하여 다양한 문서 처리 작업을 쉽게 수행할 수 있도록 돕습니다.

### 1. URL에서 문서 파싱하기

로컬 파일 경로나 원격 URL에서 문서를 파싱할 수 있습니다.

```swift
import Dendrite
import Foundation

func parseDocumentFromURL() async {
    // 로컬 파일 URL 예시
    guard let localFileURL = Bundle.main.url(forResource: "my_document", withExtension: "pdf") else {
        print("로컬 파일을 찾을 수 없습니다.")
        return
    }

    // 원격 URL 예시
    guard let remoteURL = URL(string: "https://example.com/document.html") else {
        print("유효하지 않은 URL입니다.")
        return
    }

    do {
        // 로컬 PDF 파일 파싱 (기본 설정)
        let pdfDocument = try await Dendrite.parse(from: localFileURL)
        print("--- PDF 파싱 결과 ---")
        print("콘텐츠 (일부): \(pdfDocument.content.prefix(200))... ")
        print("제목: \(pdfDocument.metadata.title ?? "없음")")
        if case .pdf(let pdfMeta) = pdfDocument.metadata.sourceDetails {
            print("총 페이지: \(pdfMeta.totalPages)")
            print("OCR 처리 페이지: \(pdfMeta.ocrProcessedPages)")
            print("암호화 여부: \(pdfMeta.isEncrypted)")
        }

        // 원격 HTML 파일 파싱 (기본 설정)
        let htmlDocument = try await Dendrite.parse(from: remoteURL)
        print("\n--- HTML 파싱 결과 ---")
        print("콘텐츠 (일부): \(htmlDocument.content.prefix(200))... ")
        print("제목: \(htmlDocument.metadata.title ?? "없음")")
        print("링크 수: \(htmlDocument.metadata.links?.count ?? 0)")

    } catch {
        if let dendriteError = error as? DendriteError {
            print("Dendrite 오류 발생: \(dendriteError.localizedDescription)")
        } else {
            print("알 수 없는 오류 발생: \(error.localizedDescription)")
        }
    }
}
```

### 2. `Data`로부터 문서 파싱하기

메모리에 로드된 `Data` 객체와 `UTType`을 사용하여 문서를 파싱할 수 있습니다.

```swift
import Dendrite
import Foundation
import UniformTypeIdentifiers

func parseDocumentFromData() async {
    let htmlString = "<h1>Welcome</h1><p>This is a <strong>test</strong> HTML string.</p>"
    guard let htmlData = htmlString.data(using: .utf8) else { return }

    do {
        let document = try await Dendrite.parse(data: htmlData, fileType: .html)
        print("--- Data 파싱 결과 ---")
        print("콘텐츠: \(document.content)")
        print("제목: \(document.metadata.title ?? "없음")")
    } catch {
        if let dendriteError = error as? DendriteError {
            print("Dendrite 오류 발생: \(dendriteError.localizedDescription)")
        } else {
            print("알 수 없는 오류 발생: \(error.localizedDescription)")
        }
    }
}
```

### 3. HTML을 Markdown으로 변환하기

`Dendrite.Converter`를 사용하여 HTML 문자열을 Markdown으로 변환할 수 있습니다.

```swift
import Dendrite

func convertHTMLToMarkdown() {
    let html = """
    <h1>제목</h1>
    <p>이것은 <strong>강조된</strong> 텍스트와 <a href="https://example.com">링크</a>가 있는 단락입니다.</p>
    <ul>
        <li>항목 1</li>
        <li>항목 2</li>
    </ul>
    <pre><code class="language-swift">let x = 10</code></pre>
    """
    
    do {
        let markdown = try Dendrite.Converter.htmlToMarkdown(from: html)
        print("--- HTML to Markdown 변환 결과 ---")
        print(markdown)
        /*
        # 제목

        이것은 **강조된** 텍스트와 [링크](https://example.com)가 있는 단락입니다.

        - 항목 1
        - 항목 2

        ```swift
        let x = 10
        ```
        */
    } catch {
        print("변환 실패: \(error.localizedDescription)")
    }
}
```

### 4. 이미지에서 텍스트 추출 (OCR)

`Dendrite.OCR`을 사용하여 `CGImage`로부터 텍스트를 인식할 수 있습니다.

```swift
import Dendrite
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

func performOCRFromImage() async {
    // 테스트용 CGImage 생성 (실제 앱에서는 이미지 파일에서 로드)
    // 이 예제는 macOS/iOS 환경에서 실행 가능하도록 플랫폼별 분기 처리
    var cgImage: CGImage?
    #if canImport(AppKit)
    let nsImage = NSImage(size: NSSize(width: 100, height: 50), flipped: false) { rect in
        NSColor.white.drawSwatch(in: rect)
        let text = "Hello OCR"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        text.draw(at: NSPoint(x: 10, y: 10), withAttributes: attributes)
        return true
    }
    cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #elseif canImport(UIKit)
    let uiImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        let text = "Hello OCR"
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
        text.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
    }
    cgImage = uiImage.cgImage
    #endif

    guard let image = cgImage else {
        print("CGImage 생성 실패.")
        return
    }

    // OCR 설정 커스터마이징 (예: 한국어, 영어 인식, 정확도 우선)
    let config = OCRConfiguration(languages: ["ko-KR", "en-US"], recognitionLevel: .accurate)
    
    do {
        let result = try await Dendrite.OCR.perform(on: image, configuration: config)
        print("--- OCR 결과 ---")
        print("인식된 텍스트: \(result.text)")
        print("신뢰도: \(result.confidence)")
    } catch {
        print("OCR 실패: \(error.localizedDescription)")
    }
}
```

### 5. 커스텀 설정 및 파서 주입

`DendriteConfig`를 통해 라이브러리의 동작을 세밀하게 제어할 수 있습니다.

```swift
import Dendrite
import Foundation
import UniformTypeIdentifiers

// 예시: 커스텀 파서 (매우 간단한 XML 파서)
struct CustomXMLParser: ParserProtocol {
    let supportedTypes: [UTType] = [.xml] // UTType.xml은 iOS 14+에서 사용 가능

    func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        // 실제 XML 파싱 로직 (여기서는 간단히 텍스트만 추출)
        let content = xmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        var metadata = DocumentMetadata()
        metadata.title = "Custom XML Document"
        
        return ParsedDocument(content: content, metadata: metadata)
    }
}

func useCustomConfiguration() async {
    // PDF 파서 설정: 텍스트 임계값을 높여 OCR을 덜 자주 수행하도록 설정
    let pdfConfig = PDFParserConfiguration(textThreshold: 200)

    // 커스텀 파서와 PDF 설정을 포함하는 DendriteConfig 생성
    let customConfig = DendriteConfig(
        customParsers: [CustomXMLParser()], // 기본 파서 목록에 추가하거나 대체
        pdfConfiguration: pdfConfig
    )

    // XML 데이터 파싱 예시
    let xmlString = "<root><item>Hello</item><item>World</item></root>"
    guard let xmlData = xmlString.data(using: .utf8) else { return }

    do {
        let document = try await Dendrite.parse(data: xmlData, fileType: .xml, config: customConfig)
        print("--- 커스텀 XML 파싱 결과 ---")
        print("콘텐츠: \(document.content)")
        print("제목: \(document.metadata.title ?? "없음")")
    } catch {
        if let dendriteError = error as? DendriteError {
            print("Dendrite 오류 발생: \(dendriteError.localizedDescription)")
        } else {
            print("알 수 없는 오류 발생: \(error.localizedDescription)")
        }
    }

    // PDF 파싱 시 커스텀 설정 적용 예시 (실제 PDF 데이터 필요)
    // let pdfURL = URL(fileURLWithPath: "/path/to/your/document.pdf")
    // let customPdfDocument = try await Dendrite.parse(from: pdfURL, config: customConfig)
    // print("커스텀 설정으로 파싱된 PDF: \(customPdfDocument.metadata.sourceDetails?.pdfMetadata?.ocrProcessedPages ?? -1)")
}
```

### 6. 오류 처리

Dendrite는 모든 예상 가능한 오류를 `DendriteError` 열거형으로 정의하여 체계적인 오류 처리를 돕습니다.

```swift
import Dendrite
import Foundation

func demonstrateErrorHandling() async {
    // 1. 지원하지 않는 파일 타입 오류
    let unsupportedURL = URL(fileURLWithPath: "file:///path/to/document.xyz")
    do {
        _ = try await Dendrite.parse(from: unsupportedURL)
    } catch let error as DendriteError {
        if case .unsupportedFileType(let ext) = error {
            print("오류: 지원하지 않는 파일 타입 - .\(ext)")
        } else {
            print("예상치 못한 Dendrite 오류: \(error.localizedDescription)")
        }
    } catch {
        print("알 수 없는 오류: \(error.localizedDescription)")
    }

    // 2. 파일 읽기 실패 오류
    let nonExistentURL = URL(fileURLWithPath: "file:///non/existent/file.txt")
    do {
        _ = try await Dendrite.parse(from: nonExistentURL)
    } catch let error as DendriteError {
        if case .fileReadFailed(let url, let underlyingError) = error {
            print("오류: 파일 읽기 실패 - \(url.lastPathComponent), 원인: \(underlyingError.localizedDescription)")
        }
    } catch {
        print("알 수 없는 오류: \(error.localizedDescription)")
    }

    // 3. 파싱 실패 오류 (예: 손상된 PDF)
    // 실제 손상된 PDF 파일이 필요합니다.
    // guard let corruptedPDFURL = Bundle.main.url(forResource: "corrupted", withExtension: "pdf") else { return }
    // do {
    //     _ = try await Dendrite.parse(from: corruptedPDFURL)
    // } catch let error as DendriteError {
    //     if case .pdfDocumentLoadFailure = error {
    //         print("오류: PDF 문서 로드 실패 (손상된 파일)")
    //     } else if case .parsingFailed(let parserName, let underlyingError) = error {
    //         print("오류: \(parserName) 파싱 실패 - 원인: \(underlyingError.localizedDescription)")
    //     } else {
    //         print("예상치 못한 Dendrite 오류: \(error.localizedDescription)")
    //     }
    // } catch {
    //     print("알 수 없는 오류: \(error.localizedDescription)")
    // }
}
```

## 📚 Public API 참조

Dendrite는 명확하고 잘 정의된 Public API를 통해 라이브러리의 모든 기능을 노출합니다.

### `public enum Dendrite`

라이브러리의 메인 진입점(Facade)입니다. 모든 핵심 파싱, 변환, OCR 기능에 접근할 수 있습니다.

*   `static func parse(from url: URL, config: DendriteConfig = .default) async throws -> ParsedDocument`
    *   URL로부터 문서를 파싱합니다.
    *   **Parameters**:
        *   `url`: 파싱할 파일의 URL. 로컬 및 원격 URL을 모두 지원합니다.
        *   `config`: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `.default`입니다.
    *   **Returns**: 파싱된 텍스트와 메타데이터를 담은 ``ParsedDocument``.
    *   **Throws**: ``DendriteError`` (파일 읽기 실패, 지원하지 않는 파일 타입 또는 파싱 실패 시).
*   `static func parse(data: Data, fileType: UTType, config: DendriteConfig = .default) async throws -> ParsedDocument`
    *   메모리의 `Data`로부터 문서를 파싱합니다.
    *   **Parameters**:
        *   `data`: 파싱할 원본 데이터.
        *   `fileType`: 데이터의 `UTType` (예: `.html`, `.pdf`).
        *   `config`: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `.default`입니다.
    *   **Returns**: 파싱된 텍스트와 메타데이터를 담은 ``ParsedDocument``.
    *   **Throws**: ``DendriteError`` (지원하지 않는 파일 타입 또는 파싱 실패 시).

#### `public struct Dendrite.Converter`

문서 형식 변환을 위한 유틸리티 네임스페이스입니다.

*   `static func htmlToMarkdown(from html: String) throws -> String`
    *   HTML 문자열을 Markdown 문자열로 변환합니다.
    *   **Parameters**:
        *   `html`: 변환할 HTML 문자열.
    *   **Returns**: 변환된 Markdown 문자열.
    *   **Throws**: HTML 파싱 또는 변환 과정에서 오류가 발생할 수 있습니다.

#### `public enum Dendrite.OCR`

OCR(광학 문자 인식) 기능을 위한 유틸리티 네임스페이스입니다.

*   `static func perform(on cgImage: CGImage, configuration: OCRConfiguration = .init()) async throws -> OCRResult`
    *   주어진 이미지(`CGImage`)에서 텍스트를 인식합니다.
    *   **Parameters**:
        *   `cgImage`: OCR을 수행할 `CGImage` 객체.
        *   `configuration`: OCR 언어, 정확도 등을 포함하는 설정 객체.
    *   **Returns**: 인식된 텍스트와 평균 신뢰도를 포함하는 ``OCRResult`` 객체.
    *   **Throws**: Vision 프레임워크가 텍스트를 인식하는 과정에서 오류가 발생할 수 있습니다.

### `public struct DendriteConfig: Sendable`

`Dendrite` 라이브러리의 동작을 구성하는 설정 객체입니다.

*   `init(customParsers: [any ParserProtocol]? = nil, pdfConfiguration: PDFParserConfiguration = .init())`
    *   `Dendrite` 라이브러리의 설정을 초기화합니다.
    *   **Parameters**:
        *   `customParsers`: 기본 파서 세트를 대체하거나 추가할 커스텀 파서 배열. `nil`인 경우, 기본으로 제공되는 파서 세트가 사용됩니다.
        *   `pdfConfiguration`: PDF 파서(`PDFParser`)에 적용할 설정. ``PDFParserConfiguration``을 참고하세요.
*   `static let `default`: DendriteConfig`
    *   `Dendrite` 라이브러리의 기본 설정입니다.

### `public enum DendriteError: Error, LocalizedError`

`Dendrite` 라이브러리에서 발생할 수 있는 오류를 정의합니다.

*   `case fileReadFailed(url: URL, underlyingError: Error)`: 파일 읽기 실패.
*   `case unsupportedFileType(fileExtension: String)`: 지원하지 않는 파일 형식.
*   `case decodingFailed(encoding: String)`: 데이터 디코딩 실패.
*   `case parsingFailed(parserName: String, underlyingError: Error)`: 파싱 과정 실패.
*   `case pdfDocumentLoadFailure`: PDF 문서 로드 실패.
*   `case pdfPageNotFound(pageNumber: Int)`: PDF 페이지를 찾을 수 없음.
*   `case pdfImageRenderingFailure`: PDF 페이지 이미지 렌더링 실패.

### `public struct ParsedDocument: Sendable`

모든 파서가 반환하는 최종 결과물을 나타내는 불변 구조체입니다.

*   `let content: String`: 문서에서 추출된 주요 텍스트 내용.
*   `let metadata: DocumentMetadata`: 문서에서 추출한 구조화된 메타데이터.

### `public struct DocumentMetadata: Sendable`

문서에서 추출된 메타데이터를 타입-안전(Type-Safe) 방식으로 담는 구조체입니다.

*   `var title: String?`
*   `var author: String?`
*   `var creationDate: Date?`
*   `var modificationDate: Date?`
*   `var links: [String]?`
*   `var processingTime: TimeInterval?`
*   `var sourceDetails: SourceSpecificMetadata?`: 파일 형식별 고유 메타데이터.

#### `public enum DocumentMetadata.SourceSpecificMetadata: Sendable`

파일 형식별 고유 메타데이터를 타입-안전하게 저장하는 열거형입니다.

*   `case pdf(PDFMetadata)`
*   `case markdown(MarkdownMetadata)`
*   `case html(HTMLMetadata)`

#### `public struct DocumentMetadata.PDFMetadata: Sendable`

PDF 파일의 고유 메타데이터를 담는 구조체입니다.

*   `var totalPages: Int`
*   `var ocrProcessedPages: Int`
*   `var isEncrypted: Bool`

#### `public struct DocumentMetadata.MarkdownMetadata: Sendable`

Markdown 파일의 고유 메타데이터를 담는 구조체입니다.

*   `var outline: [String]?`

#### `public struct DocumentMetadata.HTMLMetadata: Sendable`

HTML 파일의 고유 메타데이터를 담는 구조체입니다. (현재는 비어 있음)

### `public struct OCRConfiguration: Sendable`

OCR(광학 문자 인식) 기능의 동작을 구성하는 설정 객체입니다.

*   `let languages: [String]`: OCR에 사용할 언어의 배열.
*   `let recognitionLevel: VNRequestTextRecognitionLevel`: Vision OCR의 인식 수준.

### `public struct OCRResult: Sendable`

OCR(광학 문자 인식) 결과를 담는 불변 구조체입니다.

*   `let text: String`: 이미지에서 인식된 전체 텍스트.
*   `let confidence: Float`: 인식된 텍스트의 평균 신뢰도 점수.

### `public struct PDFParserConfiguration: Sendable`

`PDFParser`의 동작을 구성하는 설정 객체입니다.

*   `static let defaultTextThreshold = 50`
*   `let textThreshold: Int`: 네이티브 텍스트 추출 후, 텍스트의 길이가 이 값보다 작을 경우 OCR을 수행합니다.
*   `let ocrConfiguration: OCRConfiguration`: PDF 페이지에 OCR을 수행할 때 사용할 설정.

## 🧩 확장성

Dendrite는 프로토콜 지향 설계 원칙을 적극적으로 활용하여 높은 확장성을 제공합니다.

*   **커스텀 파서 추가**: `ParserProtocol`을 준수하는 새로운 파서를 구현하여 `DendriteConfig`를 통해 라이브러리에 주입할 수 있습니다. 이를 통해 Dendrite가 기본적으로 지원하지 않는 새로운 문서 형식을 쉽게 처리할 수 있습니다.
*   **서비스 구현체 교체**: `PDFImageRendering`, `VisionOCRServing` 등과 같은 서비스 프로토콜의 커스텀 구현체를 제공하여 특정 기능의 동작 방식을 변경하거나 최적화할 수 있습니다.

## 🧪 테스트

Dendrite는 견고한 테스트 스위트를 통해 높은 품질과 신뢰성을 보장합니다.

*   **단위 테스트**: 각 컴포넌트의 개별 기능을 독립적으로 검증합니다.
*   **통합 테스트**: 여러 컴포넌트가 함께 동작하는 전체 파싱 흐름을 검증합니다.
*   **모의 객체 활용**: 의존성 주입과 프로토콜 기반 모의(Mocking)를 통해 외부 시스템에 대한 의존성을 최소화하고 테스트의 안정성과 속도를 높입니다.
*   **리소스 기반 테스트**: `Tests/DendriteTests/Resources/` 디렉토리에 있는 실제 파일들을 사용하여 라이브러리의 파싱 기능을 심층적으로 검증합니다.

자세한 테스트 전략 및 케이스는 [TESTCASE.md](TESTCASE.md) 파일을 참조하십시오.

## 🤝 기여

Dendrite 프로젝트에 기여하는 것을 환영합니다! 버그 보고, 기능 제안, 코드 기여 등 어떤 형태의 기여든 좋습니다.

1.  이 저장소를 포크(Fork)합니다.
2.  새로운 브랜치를 생성합니다: `git checkout -b feature/your-feature-name`
3.  변경 사항을 커밋합니다: `git commit -m 'Add: Your feature'`
4.  원격 저장소에 푸시합니다: `git push origin feature/your-feature-name`
5.  Pull Request를 생성합니다.

## 📞 문의 및 지원

질문, 제안 또는 문제가 발생하면 GitHub Issues를 통해 문의해 주십시오.

---

**[GitHub 저장소 방문하기](https://github.com/AxiomOrient/Dendrite)**
