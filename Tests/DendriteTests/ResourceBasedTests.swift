

// Tests/DendriteTests/ResourceBasedTests.swift

import Testing
import Foundation
import UniformTypeIdentifiers
@testable import Dendrite

/// `Tests/DendriteTests/Resources/` 디렉토리의 실제 파일들을 기반으로
/// `Dendrite` 라이브러리의 파싱 기능을 검증하는 테스트 스위트입니다.
@Suite("Resource-Based Parsing Tests", .tags(.integration, .slow))
final class ResourceBasedTests {

    // MARK: - Success Cases

    /// **의도:** `sample.md` 파일을 파싱하여 콘텐츠와 메타데이터를 정확히 추출하는지 검증합니다。
    @Test("Markdown 파일 파싱: sample.md")
    func testParsing_sampleMarkdown() async throws {
        // Arrange
        let url = try fixture(name: "sample.md")
        let originalContent = try String(contentsOf: url)
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Print for verification
        print("--- [Test: sample.md] ---")
//        print("Original Content (first 100 chars):\n\(originalContent)...")
        print("Parsed Content (first 100 chars):\n\(document.content)...")
        print("Parsed Metadata:\n\(document.metadata)")
        print("--------------------------")
        
        // Assert
        #expect(document.content.contains("Preamble: AI Communication Foundational Principles"))
        #expect(document.metadata.title == "Preamble: AI Communication Foundational Principles")
        #expect(document.metadata.links?.contains("https://www.google.com") == true)
        #expect(document.metadata.sourceDetails?.markdownMetadata?.outline?.isEmpty == false)
    }

    /// **의도:** `sample.txt` 파일을 파싱하여 원본 콘텐츠를 정확히 반환하는지 검증합니다.
    @Test("Plain Text 파일 파싱: sample.txt")
    func testParsing_samplePlainText() async throws {
        // Arrange
        let url = try fixture(name: "sample.txt")
        let originalContent = try String(contentsOf: url)
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Print for verification
        print("--- [Test: sample.txt] ---")
        print("Original Content (first 100 chars):\n\(originalContent.prefix(100))...")
        print("Parsed Content (first 100 chars):\n\(document.content.prefix(100))...")
        print("Parsed Metadata:\n\(document.metadata)")
        print("--------------------------")
        
        // Assert
        #expect(document.content.contains("Wellness Vibe: 지금 시작하세요, AI와 함께하는 당신만의 생기 넘치는 하루 여정"))
        #expect(document.metadata.title == nil)
    }

    /// **의도:** `agent.html` 파일을 파싱하여 의미있는 Markdown 콘텐츠와 메타데이터를 추출하는지 검증합니다.
    @Test("HTML 파일 파싱: agent.html")
    func testParsing_agentHTML() async throws {
        // Arrange
        let url = try fixture(name: "agent.html")
        let originalContent = try String(contentsOf: url)
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Print for verification
        print("--- [Test: agent.html] ---")
        print("Original Content (first 100 chars):\n\(originalContent.prefix(100))...")
        print("Parsed Content (first 100 chars):\n\(document.content.prefix(100))...")
        print("Parsed Metadata:\n\(document.metadata)")
        print("--------------------------")
        
        // Assert
        #expect(document.content.contains("AI 아키텍처 가이드"))
        #expect(document.content.contains("차세대 AI, Python을 넘어서"))
        #expect(document.metadata.title == "차세대 AI 기술 스택 대시보드")
        #expect(document.metadata.links?.isEmpty == false)
    }

    /// **의도:** `sample.pdf` (텍스트 기반) 파일을 파싱하여 텍스트 콘텐츠와 메타데이터를 정확히 추출하는지 검증합니다.
    @Test("PDF 파일 파싱: sample.pdf (텍스트 기반)")
    func testParsing_samplePDF_textBased() async throws {
        // Arrange
        let url = try fixture(name: "sample.pdf")
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Print for verification
        print("--- [Test: sample.pdf (text-based)] ---")
        print("Parsed Content (first 100 chars):\n\(document.content.prefix(100))...")
        print("Parsed Metadata:\n\(document.metadata)")
        print("------------------------------------")
        
        // Assert
        #expect(document.content.contains("AFD 플랫폼 개발 완료 보고서"))
        #expect(document.metadata.title == nil) // sample.pdf에는 제목 메타데이터 없음
        #expect(document.metadata.sourceDetails?.pdfMetadata?.totalPages == 12)
        #expect(document.metadata.sourceDetails?.pdfMetadata?.ocrProcessedPages == 0) // 텍스트 기반이므로 OCR 미실행
    }

    /// **의도:** `sample_image.pdf` (이미지 기반) 파일을 파싱하여 OCR을 통해 텍스트를 추출하는지 검증합니다.
    ///
    /// OCR의 정확도는 환경에 따라 달라질 수 있으므로, OCR이 수행되었고 비어있지 않은 텍스트가 추출되었는지에 초점을 맞춥니다.
    @Test("PDF 파일 파싱: sample_image.pdf (이미지 기반)")
    func testParsing_sampleImagePDF_ocrBased() async throws {
        // Arrange
        let url = try fixture(name: "sample_image.pdf")
        
        // Act
        let document = try await Dendrite.parse(from: url)
        
        // Print for verification
        print("--- [Test: sample_image.pdf (image-based)] ---")
        print("Parsed Content (first 100 chars):\n\(document.content.prefix(100))...")
        print("Parsed Metadata:\n\(document.metadata)")
        print("----------------------------------------")
        
        // Assert
        #expect(!document.content.isEmpty, "OCR 결과 텍스트는 비어있지 않아야 합니다.")
        #expect(document.content.count > 5, "OCR 결과 텍스트는 최소 5자 이상이어야 합니다.") // 최소 길이 검증
        #expect(document.metadata.sourceDetails?.pdfMetadata?.totalPages == 1)
        #expect(document.metadata.sourceDetails?.pdfMetadata?.ocrProcessedPages == 1) // 이미지 기반이므로 OCR 실행
    }

    // MARK: - Failure Cases

    /// **의도:** `corrupted.pdf` (손상된) 파일을 파싱할 때 `pdfDocumentLoadFailure` 오류를 던지는지 검증합니다.
    @Test("오류: 손상된 PDF 파일 (corrupted.pdf)")
    func testParsing_corruptedPDF_throwsError() async throws {
        // Arrange
        let url = try fixture(name: "corrupted.pdf")
        
        // Act & Assert
        let thrownError = try await #require(throws: DendriteError.self) {
            _ = try await Dendrite.parse(from: url)
        }
        
        // Print for verification
        print("--- [Test: corrupted.pdf] ---")
        print("Thrown Error: \(thrownError)")
        print("-----------------------------")
        
        #expect(thrownError == .pdfDocumentLoadFailure)
    }

    /// **의도:** `unsupported.zip` (지원하지 않는) 파일을 파싱할 때 `unsupportedFileType` 오류를 던지는지 검증합니다.
    @Test("오류: 지원하지 않는 파일 타입 (unsupported.zip)")
    func testParsing_unsupportedZip_throwsError() async throws {
        // Arrange
        let url = try fixture(name: "unsupported.zip")
        
        // Act & Assert
        let thrownError = try await #require(throws: DendriteError.self) {
            _ = try await Dendrite.parse(from: url)
        }
        
        // Print for verification
        print("--- [Test: unsupported.zip] ---")
        print("Thrown Error: \(thrownError)")
        print("-------------------------------")
        
        guard case .unsupportedFileType(let fileExtension) = thrownError else {
            #expect(Bool(false), "예상과 다른 오류가 발생했습니다: \(thrownError)")
            return
        }
        #expect(fileExtension == "zip")
    }
}

// MARK: - Helper Extensions
private extension DocumentMetadata.SourceSpecificMetadata {
    var markdownMetadata: DocumentMetadata.MarkdownMetadata? {
        guard case .markdown(let meta) = self else { return nil }
        return meta
    }
    
    var pdfMetadata: DocumentMetadata.PDFMetadata? {
        guard case .pdf(let meta) = self else { return nil }
        return meta
    }
    
    var htmlMetadata: DocumentMetadata.HTMLMetadata? {
        guard case .html(let meta) = self else { return nil }
        return meta
    }
}
