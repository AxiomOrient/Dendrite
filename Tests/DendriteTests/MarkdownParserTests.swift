import Testing
@testable import Dendrite
import UniformTypeIdentifiers

@Suite("Markdown Parser Tests")
struct MarkdownParserTests {

    var parser: MarkdownParser!
    var sampleMarkdownData: Data!

    init() async throws {
        parser = MarkdownParser()
        
        // Load sample.md from Resources
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "md") else {
            Issue.record("Could not find sample.md in test bundle.")
            throw FixtureError(path: "sample.md", message: "Test resource not found.")
        }
        sampleMarkdownData = try Data(contentsOf: url)
    }

    @Test("마크다운 파싱 및 메타데이터 추출 검증", .tags(.unit, .parser))
    func testMarkdownParsingAndMetadataExtraction() async throws {
        // Given
        let type = UTType("net.daringfireball.markdown")!

        // When
        let (nodes, metadata) = try await parser.parse(data: sampleMarkdownData, type: type)

        // Assert
        // 1. 노드 검증 (일부 내용 포함 여부)
        let plainTextContent = nodes.map { $0.plainText }.joined(separator: "\n")
        #expect(plainTextContent.contains("This is a test document."))
        #expect(plainTextContent.contains("Universal Engineering Principles"))

        // 2. 메타데이터 검증
        #expect(metadata.title == "Preamble: AI Communication Foundational Principles", "제목이 정확히 추출되어야 합니다.")
        
        let links = metadata.links
        #expect(links.contains(URL(string: "https://www.axiomorient.com")!))
        #expect(links.contains(URL(string: "https://www.google.com")!))
        
        // 3. 소스 상세 정보 (Markdown 특정 메타데이터) 검증
        guard case .markdown(let markdownMeta) = metadata.sourceDetails else {
            Issue.record("Source details should be MarkdownMetadata.")
            throw TestError(description: "Invalid source details type.")
        }
        
        // 3.1. 개요(Outline) 검증
        let outline = markdownMeta.outline
        #expect(outline.count > 5, "개요가 5개 이상이어야 합니다.")
        #expect(outline.contains(where: { $0.title == "Preamble: AI Communication Foundational Principles" }))
        #expect(outline.contains(where: { $0.title == "Tier 0 – Core AI Interaction Principles" }))
        
        // 3.2. 테이블 검증
        let tables = markdownMeta.tables
        #expect(tables.count == 2, "테이블이 2개 파싱되어야 합니다.")
        
        // 첫 번째 테이블 검증
        let firstTable = try #require(tables.first)
        #expect(firstTable.headers == ["Principle", "What It Means in Practice"])
        #expect(firstTable.rowCount == 4)
        
        // 두 번째 테이블 검증
        let secondTable = try #require(tables.last)
        #expect(secondTable.headers == ["Anti-Pattern", "Why It Hurts", "Fix"])
        #expect(secondTable.rowCount == 6)
        
        // 3.3. 코드 블록 검증
        let codeBlocks = markdownMeta.codeBlocks
        #expect(codeBlocks.count > 0, "코드 블록이 파싱되어야 합니다.")
        #expect(codeBlocks.contains(where: { $0.language == "swift" }))
        
        // 3.4. Front Matter 검증
        let frontMatter = markdownMeta.frontMatter
        #expect(frontMatter["title"] == "Preamble: AI Communication Foundational Principles")
        #expect(frontMatter["author"] == "Gemini CLI")
    }

    @Test("빈 마크다운 문서 처리", .tags(.unit, .parser))
    func testEmptyMarkdown() async throws {
        // Given
        let emptyData = Data()
        let type = UTType("net.daringfireball.markdown")!

        // When
        let (nodes, metadata) = try await parser.parse(data: emptyData, type: type)

        // Assert
        #expect(nodes.isEmpty)
        #expect(metadata.title == nil)
    }

    @Test("Front Matter만 있는 마크다운 문서 처리", .tags(.unit, .parser))
    func testMarkdownWithOnlyFrontMatter() async throws {
        // Given
        let frontMatterOnly = """
---
title: Test Title
author: Test Author
---
""".data(using: .utf8)!
        let type = UTType("net.daringfireball.markdown")!

        // When
        let (nodes, metadata) = try await parser.parse(data: frontMatterOnly, type: type)

        // Assert
        #expect(nodes.isEmpty)
        #expect(metadata.title == "Test Title")
        #expect(metadata.author == "Test Author")
    }
}