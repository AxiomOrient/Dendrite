

// Tests/DendriteTests/HTMLConverterTests.swift

import Testing
@testable import Dendrite

/// `MarkdownFromHTMLConverter`의 변환 규칙을 검증하는 유닛 테스트 스위트입니다.
@Suite("HTML to Markdown Converter Unit Tests", .tags(.unit, .fast))
final class HTMLConverterTests {
    
    private let converter = MarkdownFromHTMLConverter()
    
    /// 테스트 케이스를 정의하는 Sendable 구조체
    struct HTMLTestCase: Sendable {
        let name: String
        let input: String
        let expected: String
    }
    
    /// 매개변수화된 테스트에 사용될 테스트 케이스 데이터입니다.
    static let testCases: [HTMLTestCase] = [
        // Headers
        .init(name: "H1", input: "<h1>Title</h1>", expected: "# Title"),
        .init(name: "H2", input: "<h2>Subtitle</h2>", expected: "## Subtitle"),
        .init(name: "H6", input: "<h6>Tiny Header</h6>", expected: "###### Tiny Header"),
        // Paragraph
        .init(name: "Paragraph", input: "<p>Hello, world.</p>", expected: "Hello, world."),
        // Link
        .init(name: "Link", input: "<a href=\"https://example.com\">Click me</a>", expected: "[Click me](https://example.com)"),
        // Lists
        .init(name: "Unordered List", input: "<ul><li>One</li><li>Two</li></ul>", expected: "- One\n- Two"),
        .init(name: "Ordered List", input: "<ol><li>First</li><li>Second</li></ol>", expected: "1. First\n2. Second"),
        // Code
        .init(name: "Inline Code", input: "<p>Use the `<code>main</code>` function.</p>", expected: "Use the ``main`` function."),
        .init(name: "Code Block", input: "<pre><code class=\"language-swift\">let x = 1</code></pre>", expected: "```swift\nlet x = 1\n```"),
        // Nested & Unsupported
        .init(name: "Nested Tags", input: "<p>See details in <strong><a href=\"#\">this link</a></strong>.</p>", expected: "See details in [this link](#)."),
        .init(name: "Unsupported Tags", input: "<div><p>Content inside a div.</p></div>", expected: "Content inside a div.")
    ]
    
    /// **의도:** 다양한 HTML 태그가 올바른 Markdown으로 변환되는지 검증합니다.
    @Test("HTML 태그 변환 검증", arguments: testCases)
    func testHTMLTagConversion(testCase: HTMLTestCase) throws {
        // Arrange
        let html = "<body>\(testCase.input)</body>"
        
        // Act
        let result = try converter.convert(html)
        
        // Assert
        #expect(result == testCase.expected, "'\(testCase.name)' 태그 변환이 예상과 다릅니다. Result: \(result), Expected: \(testCase.expected)")
    }
}
