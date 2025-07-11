
import Testing
@testable import Dendrite
import UniformTypeIdentifiers

@Suite("Dendrite Core Tests")
struct DendriteTests {

    var tokenizer: AppleNLTokenizer!

    init() {
        tokenizer = AppleNLTokenizer()
    }

    @Test("마크다운 문서 처리 및 청크 검증", .tags(.integration, .chunking, .parser))
    func testMarkdownProcessing() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "md") else {
            Issue.record("Could not find sample.md in test bundle.")
            throw FixtureError(path: "sample.md", message: "Test resource not found.")
        }

        // Act
        let processedDocument = try await Dendrite.process(from: url, tokenizer: tokenizer)

        // Assert
        #expect(processedDocument.id.value == "sample.md")
        #expect(processedDocument.nodes.count > 0)
        #expect(processedDocument.chunks.count > 0)
        #expect(processedDocument.statistics.totalTokenCount.value > 0)
        
        #expect(processedDocument.metadata.title == "Preamble: AI Communication Foundational Principles")
        #expect(processedDocument.metadata.links.contains(URL(string: "https://www.google.com")!))
        
        guard case .markdown(let markdownMeta) = processedDocument.metadata.sourceDetails else {
            Issue.record("Source details should be MarkdownMetadata.")
            throw TestError(description: "Invalid source details type.")
        }
        #expect(!markdownMeta.outline.isEmpty, "개요가 파싱되어야 합니다.")
        #expect(!markdownMeta.tables.isEmpty, "테이블이 최소 1개 이상 파싱되어야 합니다.")

        // 첫 번째 테이블 검증
        let firstTable = try #require(markdownMeta.tables.first)
        #expect(firstTable.headers == ["Principle", "What It Means in Practice"])
        #expect(firstTable.rowCount == 4)

        // 청크 내용 검증 (일부)
        let firstChunk = try #require(processedDocument.chunks.first)
        #expect(firstChunk.content.contains("This is a test document."))
        #expect(firstChunk.tokenCount.value > 0)
        #expect(firstChunk.breadcrumb.path.contains("Preamble"))
    }

    @Test("HTML 문서 처리 및 청크 검증", .tags(.integration, .chunking, .parser))
    func testHTMLProcessing() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "agent", withExtension: "html") else {
            Issue.record("Could not find agent.html in test bundle.")
            throw FixtureError(path: "agent.html", message: "Test resource not found.")
        }

        // Act
        let processedDocument = try await Dendrite.process(from: url, tokenizer: tokenizer)

        // Assert
        #expect(processedDocument.id.value == "agent.html")
        #expect(processedDocument.nodes.count > 0)
        #expect(processedDocument.chunks.count > 0)
        #expect(processedDocument.statistics.totalTokenCount.value > 0)
        #expect(processedDocument.metadata.title == "Agent - Wikipedia")
        #expect(processedDocument.metadata.links.contains(URL(string: "https://en.wikipedia.org/wiki/Agent")!))
    }

    @Test("Plain Text 문서 처리 및 청크 검증", .tags(.integration, .chunking, .parser))
    func testPlainTextProcessing() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "txt") else {
            Issue.record("Could not find sample.txt in test bundle.")
            throw FixtureError(path: "sample.txt", message: "Test resource not found.")
        }

        // Act
        let processedDocument = try await Dendrite.process(from: url, tokenizer: tokenizer)

        // Assert
        #expect(processedDocument.id.value == "sample.txt")
        #expect(processedDocument.nodes.count == 1)
        #expect(processedDocument.chunks.count == 1)
        #expect(processedDocument.statistics.totalTokenCount.value > 0)
        #expect(processedDocument.metadata.title == nil)
        #expect(processedDocument.chunks.first?.content.contains("This is a sample plain text document.") == true)
    }

    @Test("PDF 문서 처리 및 청크 검증", .tags(.integration, .chunking, .parser, .slow))
    func testPDFProcessing() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "pdf") else {
            Issue.record("Could not find sample.pdf in test bundle.")
            throw FixtureError(path: "sample.pdf", message: "Test resource not found.")
        }

        // Act & Assert
        await #expect(throws: DendriteError.self) {
            _ = try await Dendrite.process(from: url, tokenizer: tokenizer)
        } 
    }

    @Test("이미지 PDF 문서 처리 및 청크 검증", .tags(.integration, .chunking, .parser, .slow))
    func testImagePDFProcessing() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "sample_image", withExtension: "pdf") else {
            Issue.record("Could not find sample_image.pdf in test bundle.")
            throw FixtureError(path: "sample_image.pdf", message: "Test resource not found.")
        }

        // Act & Assert
        await #expect(throws: DendriteError.self) {
            _ = try await Dendrite.process(from: url, tokenizer: tokenizer)
        }
    }

    @Test("지원하지 않는 파일 타입 처리", .tags(.unit, .parser))
    func testUnsupportedFileType() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "unsupported", withExtension: "zip") else {
            Issue.record("Could not find unsupported.zip in test bundle.")
            throw FixtureError(path: "unsupported.zip", message: "Test resource not found.")
        }

        // Act & Assert
        await #expect(throws: DendriteError.self) {
            _ = try await Dendrite.process(from: url, tokenizer: tokenizer)
        } 
    }

    @Test("손상된 PDF 파일 처리", .tags(.unit, .parser, .slow))
    func testCorruptedPDF() async throws {
        // Given
        guard let url = Bundle.module.url(forResource: "corrupted", withExtension: "pdf") else {
            Issue.record("Could not find corrupted.pdf in test bundle.")
            throw FixtureError(path: "corrupted.pdf", message: "Test resource not found.")
        }

        // Act & Assert
        await #expect(throws: DendriteError.self) {
            _ = try await Dendrite.process(from: url, tokenizer: tokenizer)
        } 
    }

    @Test("파일 읽기 실패 처리", .tags(.unit, .parser))
    func testFileReadFailed() async throws {
        // Given: A non-existent URL
        let nonExistentURL = URL(fileURLWithPath: "/path/to/nonexistent/file.txt")

        // Act & Assert
        await #expect(throws: DendriteError.self) {
            _ = try await Dendrite.process(from: nonExistentURL, tokenizer: tokenizer)
        }
    }
}

// MARK: - Helper for TestError
struct TestError: Error, CustomStringConvertible {
    let description: String
}
