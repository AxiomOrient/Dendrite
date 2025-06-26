import Testing
import Foundation
@testable import Dendrite

// MARK: - DendriteTests

/// Dendrite 라이브러리의 핵심 기능을 검증하는 테스트 스위트입니다.
@Suite("Dendrite Core Functionality Tests")
final class DendriteTests {

    // MARK: - Test Lifecycle
    
    // 필요한 경우 여기에 @TestState, setUp, tearDown 등을 추가할 수 있습니다.

    // MARK: - Success Cases (Happy Path)

    /// **Given:** 유효한 Markdown 파일이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** 정확한 콘텐츠와 메타데이터(제목, 링크)를 포함한 `ParsedDocument`를 반환해야 합니다.
    @Test("Markdown 파싱: 유효한 파일로부터 콘텐츠와 메타데이터를 정확히 추출한다")
    func testMarkdownParsing_whenGivenValidFile_thenReturnsCorrectContentAndMetadata() async throws {
        // Arrange
        let markdownURL = try fixture(name: "sample.md")
        
        // Act
        let document = try await Dendrite.parse(from: markdownURL)
        
        // Assert
        #expect(document.content.contains("This is a test document."), "콘텐츠에 본문이 포함되어야 합니다.")
        #expect(document.metadata.title == "Preamble: AI Communication Foundational Principles", "메타데이터에 정확한 제목이 포함되어야 합니다.")
        #expect(document.metadata.links?.contains("https://www.google.com") == true, "메타데이터에 정확한 링크가 포함되어야 합니다.")
    }

    /// **Given:** 유효한 Plain Text 파일이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** 원본과 동일한 콘텐츠를 포함한 `ParsedDocument`를 반환해야 합니다.
    @Test("PlainText 파싱: 유효한 파일로부터 원본 콘텐츠를 정확히 반환한다")
    func testPlainTextParsing_whenGivenValidFile_thenReturnsCorrectContent() async throws {
        // Arrange
        let textURL = try fixture(name: "sample.txt")
        let expectedContent = "This is a plain text file."
        
        // Act
        let document = try await Dendrite.parse(from: textURL)
        
        // Assert
        #expect(document.content == expectedContent, "콘텐츠가 원본 텍스트와 정확히 일치해야 합니다.")
        #expect(document.metadata.title == nil, "일반 텍스트 파일의 제목은 nil이어야 합니다.")
    }
    
    /// **Given:** 복잡한 구조의 유효한 HTML 파일(`agent.html`)이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** 스크립트와 스타일을 제외한 핵심 의미론적 콘텐츠가 마크다운으로 변환되어야 합니다.
    @Test("HTML 파싱: 복잡한 파일로부터 의미있는 마크다운 콘텐츠를 추출한다")
    func testHTMLParsing_whenGivenComplexFile_thenReturnsSemanticMarkdown() async throws {
        // Arrange
        let htmlURL = try fixture(name: "agent.html")
        
        // Act
        let document = try await Dendrite.parse(from: htmlURL)
        
        // Assert
        #expect(document.content.contains("AI 아키텍처 가이드"), "콘텐츠에 h1 태그의 내용이 포함되어야 합니다.")
        #expect(document.content.contains("차세대 AI, Python을 넘어서"), "콘텐츠에 h2 태그의 내용이 포함되어야 합니다.")
        #expect(document.content.contains("프로덕션의 핵심으로 자리 잡으면서"), "콘텐츠에 p 태그의 내용이 포함되어야 합니다.")
        #expect(document.content.contains("Google Vertex AI:"), "콘텐츠에 li 태그의 내용이 포함되어야 합니다.")
    }

    /// **Given:** 유효한 PDF 파일(텍스트 기반)이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** 정확한 텍스트 콘텐츠와 메타데이터를 포함한 `ParsedDocument`를 반환해야 합니다.
    @Test("PDF 파싱 (텍스트): 유효한 파일로부터 텍스트 콘텐츠를 정확히 추출한다")
    func testPDFParsing_whenGivenTextBasedPDF_thenReturnsCorrectContent() async throws {
        // Arrange
        let pdfURL = try fixture(name: "sample2.pdf")
        // 테스트 로그에서 확인된 실제 PDF 파일의 내용으로 기대값을 수정합니다.
        let expectedText = "챗 GPT로 자소서를 작성하면 안되는"

        // Act
        let document = try await Dendrite.parse(from: pdfURL)

        // Assert
        #expect(document.content.contains(expectedText), "콘텐츠에 PDF의 본문 텍스트가 포함되어야 합니다.")
        #expect(document.metadata.totalPages != nil && document.metadata.totalPages! > 0, "메타데이터에 정확한 총 페이지 수가 포함되어야 합니다.")
        // 이 테스트는 텍스트가 충분하여 OCR이 실행되지 않을 것을 가정합니다.
        #expect(document.metadata.ocrProcessedPages == 0, "텍스트 기반 PDF에서는 OCR이 실행되지 않아야 합니다.")
    }

    /// **Given:** 텍스트가 거의 없는 이미지 기반 PDF 파일과 OCR 옵션이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** OCR을 통해 추출된 텍스트를 포함한 `ParsedDocument`를 반환해야 합니다.
    @Test("PDF 파싱 (OCR): 이미지 기반 파일로부터 OCR을 통해 텍스트를 추출한다")
    func testPDFParsing_whenGivenImageBasedPDF_thenPerformsOCR() async throws {
        // Arrange
        // OCR 테스트를 위해서는 스캔된 문서나 이미지로만 구성된 PDF가 필요합니다.
        let pdfURL = try fixture(name: "sample_image.pdf")
        // 중요: 이 부분은 'sample_image.pdf'를 OCR 처리했을 때 예상되는 텍스트로 수정해야 합니다.
        // OCR 품질이 낮을 수 있으므로, 인식될 가능성이 높은 핵심 단어로 검증합니다.
        let expectedOcrText = "ADF"

        // Act
        let document = try await Dendrite.parse(from: pdfURL)

        // Assert
        #expect(document.content.contains(expectedOcrText), "콘텐츠에 OCR로 추출된 텍스트가 포함되어야 합니다.")
        #expect(document.metadata.totalPages != nil && document.metadata.totalPages! > 0, "메타데이터에 정확한 총 페이지 수가 포함되어야 합니다.")
        #expect(document.metadata.ocrProcessedPages != nil && document.metadata.ocrProcessedPages! > 0, "이미지 기반 PDF에서는 OCR이 실행되어야 합니다.")
    }

    // MARK: - Failure Cases (Unhappy Path)

    /// **Given:** 지원하지 않는 파일 타입(.zip)이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** `DendriteError.unsupportedFileType` 오류를 던져야 합니다.
    @Test("오류 처리: 지원하지 않는 파일 타입에 대해 'unsupportedFileType' 오류를 던진다")
    func testParsing_whenGivenUnsupportedFileType_thenThrowsUnsupportedError() async throws {
        // Arrange
        let unsupportedURL = try fixture(name: "unsupported.zip")
        
        // Act
        do {
            _ = try await Dendrite.parse(from: unsupportedURL)
            #expect(Bool(false), "오류가 발생해야 했지만, 성공했습니다.")
        } catch let error as DendriteError {
            // Assert
            switch error {
            case .unsupportedFileType(let fileExtension):
                #expect(fileExtension == "zip", "오류에 포함된 확장자 정보가 'zip'이어야 합니다.")
            default:
                #expect(Bool(false), "예상치 못한 DendriteError 타입이 발생했습니다: \(error)")
            }
        } catch {
            #expect(Bool(false), "DendriteError가 아닌 다른 타입의 오류가 발생했습니다: \(error)")
        }
    }
    
    /// **Given:** 존재하지 않는 파일 경로가 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** `DendriteError.fileReadFailed` 오류를 던져야 합니다.
    @Test("오류 처리: 존재하지 않는 파일에 대해 'fileReadFailed' 오류를 던진다")
    func testParsing_whenGivenNonExistentFile_thenThrowsFileReadFailedError() async throws {
        // Arrange
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/file.txt")
        
        // Act
        do {
            _ = try await Dendrite.parse(from: nonExistentURL)
            #expect(Bool(false), "오류가 발생해야 했지만, 성공했습니다.")
        } catch let error as DendriteError {
            // Assert
            switch error {
            case .fileReadFailed(let url, _):
                #expect(url == nonExistentURL, "오류에 포함된 URL 정보가 정확해야 합니다.")
            default:
                #expect(Bool(false), "예상치 못한 DendriteError 타입이 발생했습니다: \(error)")
            }
        } catch {
            #expect(Bool(false), "DendriteError가 아닌 다른 타입의 오류가 발생했습니다: \(error)")
        }
    }
    
    /// **Given:** 손상된 PDF 파일이 주어졌을 때
    /// **When:** `Dendrite.parse(from:)`를 호출하면
    /// **Then:** `DendriteError.parsingFailed` 오류와 함께 내부적으로 `pdfDocumentLoadFailure`가 발생해야 합니다.
    @Test("오류 처리: 손상된 파일에 대해 'parsingFailed' 오류를 던진다")
    func testParsing_whenGivenCorruptedPDF_thenThrowsParsingFailedError() async throws {
        // Arrange
        // 'corrupted.pdf'는 실제 PDF 구조를 따르지 않는 더미 파일입니다.
        let corruptedFileURL = try fixture(name: "corrupted.pdf")
        
        // Act
        do {
            _ = try await Dendrite.parse(from: corruptedFileURL)
            #expect(Bool(false), "오류가 발생해야 했지만, 성공했습니다.")
        } catch let error as DendriteError {
            // Assert
            guard case .parsingFailed(let parserName, let underlyingError) = error else {
                return #expect(Bool(false), "예상치 못한 DendriteError 타입이 발생했습니다: \(error)")
            }
            #expect(parserName == "PDFParser", "오류를 발생시킨 파서는 'PDFParser'여야 합니다.")
            guard case .pdfDocumentLoadFailure = (underlyingError as? DendriteError) else {
                return #expect(Bool(false), "내부 오류가 예상했던 .pdfDocumentLoadFailure가 아닙니다: \(underlyingError)")
            }
        } catch {
            #expect(Bool(false), "DendriteError가 아닌 다른 타입의 오류가 발생했습니다: \(error)")
        }
    }
}

// MARK: - Helpers
private extension DendriteTests {
    
    /// 테스트용 fixture 파일의 URL을 반환합니다.
    /// - Parameter name: `Tests/DendriteTests/Resources` 폴더에 있는 파일의 이름 (확장자 포함)
    /// - Returns: 파일의 전체 URL
    /// - Throws: 파일 URL을 생성할 수 없는 경우 오류를 발생시킵니다.
    func fixture(name: String) throws -> URL {
        // Split the name into base name and extension
        let parts = name.split(separator: ".")
        guard parts.count > 1 else {
            throw FixtureError(path: name, message: "Fixture name must include an extension.")
        }
        let baseName = parts.dropLast().joined(separator: ".")
        let fileExtension = String(parts.last!)

        // Use Bundle.module to access resources copied by SPM
        guard let resourceURL = Bundle.module.url(forResource: baseName, withExtension: fileExtension) else {
            throw FixtureError(path: name, message: "Fixture not found in bundle.")
        }
        return resourceURL
    }
    
    struct FixtureError: Error, CustomStringConvertible {
        let path: String
        let message: String
        var description: String { "Fixture not found at path: \(path). Reason: \(message)" }
    }
}