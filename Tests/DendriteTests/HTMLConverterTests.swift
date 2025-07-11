import Testing
@testable import Dendrite

@Suite("HTML Converter Tests")
struct HTMLConverterTests {

    @Test("HTML을 SemanticNode로 변환 검증", .tags(.unit, .parser))
    func testHTMLToSemanticNodeConversion() throws {
        let testCases: [(name: String, html: String, expected: String)] = [
            ("H1 Tag", "<h1>Hello World</h1>", "# Hello World"),
            ("Paragraph Tag", "<p>This is a paragraph.</p>", "This is a paragraph.\n\n"),
            ("Unordered List", "<ul><li>Item 1</li><li>Item 2</li></ul>", "- Item 1\n- Item 2\n\n"),
            ("Ordered List", "<ol><li>First</li><li>Second</li></ol>", "1. First\n2. Second\n\n"),
            ("Link Tag", "<a href=\"https://example.com\">Link Text</a>", "[Link Text](https://example.com)"),
            ("Image Tag", "<img src=\"image.jpg\" alt=\"Alt Text\">", "![Alt Text](image.jpg)"),
            ("Inline Code", "<p>Some <code>inline code</code> here.</p>", "Some `inline code` here.\n\n"),
            ("Code Block", "<pre><code class=\"language-swift\">let x = 10</code></pre>", "```swift\nlet x = 10\n```\n\n"),
            ("Blockquote", "<blockquote><p>Quote text</p></blockquote>", "> Quote text\n\n"),
            ("Horizontal Rule", "<hr>", "---\n\n"),
            ("Strong Tag", "<strong>Bold Text</strong>", "**Bold Text**"),
            ("Emphasis Tag", "<em>Italic Text</em>", "*Italic Text*"),
            ("Table Tag", "<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Data 1</td><td>Data 2</td></tr></tbody></table>", "| Header 1 | Header 2 |\n| -------- | -------- |\n| Data 1 | Data 2 |\n\n"),
            ("Mixed Content", "<h1>Title</h1><p>Text with <strong>bold</strong> and <em>italic</em>.</p>", "# Title\nText with **bold** and *italic*.\n\n")
        ]

        for testCase in testCases {
            let converter = MarkdownFromHTMLConverter()
            let nodes = try converter.convert(testCase.html)
            let result = nodes.map { $0.toMarkdown }.joined()

            // Assert
            #expect(result == testCase.expected, "'\(testCase.name)' 태그 변환이 예상과 다릅니다. Result: \(result), Expected: \(testCase.expected)")
        }
    }
}