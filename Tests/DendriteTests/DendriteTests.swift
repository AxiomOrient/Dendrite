
// Tests/DendriteTests/DendriteTests.swift

import Testing
import Foundation
@testable import Dendrite

/// `Dendrite`의 최상위 API와 각 파서의 통합 동작을 검증하는 테스트 스위트입니다.
@Suite("Dendrite API & Parser Integration Tests", .tags(.integration))
final class DendriteTests {

    // MARK: - Success Cases (Happy Path)

    /// **의도:** 유효한 Markdown 파일로부터 콘텐츠와 메타데이터를 정확히 추출하는지 검증합니다.
    @Test("Markdown 파싱 성공",
          .tags(.fast))
    func testMarkdownParsing_success() async throws {
        // Arrange
        let url = try fixture(name: "sample.md")
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Assert
        #expect(document.content.contains("This is a test document."))
        #expect(document.metadata.title == "Preamble: AI Communication Foundational Principles")
        #expect(document.metadata.links?.contains("https://www.google.com") == true)
    }

    /// **의도:** 일반 텍스트 파일의 원본 콘텐츠를 정확히 반환하는지 검증합니다.
    @Test("PlainText 파싱 성공",
          .tags(.fast))
    func testPlainTextParsing_success() async throws {
        // Arrange
        let url = try fixture(name: "sample.txt")
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Assert
        #expect(document.content.contains("AI와 함께하는 당신만의 생기 넘치는 하루 여정"))
        #expect(document.metadata.title == nil)
    }
    
    /// **의도:** 복잡한 HTML 파일로부터 의미있는 콘텐츠만 Markdown으로 변환하는지 검증합니다.
    @Test("HTML 파싱 성공",
          .tags(.fast))
    func testHTMLParsing_success() async throws {
        // Arrange
        let url = try fixture(name: "agent.html")
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Assert
        #expect(document.content.contains("AI 아키텍처 가이드"))
        #expect(document.content.contains("차세대 AI, Python을 넘어서"))
        #expect(document.content.contains("프로덕션의 핵심으로 자리 잡으면서"))
        #expect(document.content.contains("Google Vertex AI:"))
        #expect(!document.content.contains("<script>"))
    }

    // MARK: - Failure Cases (Unhappy Path)

    /// **의도:** 지원하지 않는 파일 타입에 대해 `unsupportedFileType` 오류를 던지는지 검증합니다.
    @Test("오류: 지원하지 않는 파일 타입",
          .tags(.fast))
    func testParsing_throwsUnsupportedFileType() async throws {
        // Arrange
        let url = try fixture(name: "unsupported.zip")
        
        // Act
        let thrownError = try await #require(throws: DendriteError.self) {
            _ = try await Dendrite.parse(from: url)
        }
        
        // Assert
        guard case .unsupportedFileType(let fileExtension) = thrownError else {
            #expect(Bool(false), "예상과 다른 오류가 발생했습니다: \(thrownError)")
            return
        }
        #expect(fileExtension == "zip")
    }
    
    /// **의도:** 존재하지 않는 파일 경로에 대해 `fileReadFailed` 오류를 던지는지 검증합니다.
    @Test("오류: 존재하지 않는 파일",
          .tags(.fast))
    func testParsing_throwsFileReadFailed() async throws {
        // Arrange
        let url = URL(fileURLWithPath: "/non/existent/path/file.txt")
        
        // Act
        let thrownError = try await #require(throws: DendriteError.self) {
            _ = try await Dendrite.parse(from: url)
        }
        
        // Assert
        guard case .fileReadFailed(let failedURL, _) = thrownError else {
            #expect(Bool(false), "예상과 다른 오류가 발생했습니다: \(thrownError)")
            return
        }
        #expect(failedURL == url)
    }
    
    /// **의도:** 손상된 PDF 파일에 대해 `pdfDocumentLoadFailure` 오류를 던지는지 검증합니다.
    @Test("오류: 손상된 PDF 파일",
          .tags(.fast))
    func testParsing_throwsParsingFailedForCorruptedPDF() async throws {
        // Arrange
        let url = try fixture(name: "corrupted.pdf")
        
        // Act
        let thrownError = try await #require(throws: DendriteError.self) {
            _ = try await Dendrite.parse(from: url)
        }
        
        // Assert
        #expect(thrownError == .pdfDocumentLoadFailure, "예상했던 pdfDocumentLoadFailure 오류가 아닙니다: \(thrownError)")
    }
}
