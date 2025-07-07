// Sources/Dendrite/Converters/TagConverters.swift

import Foundation
import SwiftSoup

// MARK: - Tag Converter Protocol

/// HTML 태그 변환 전략이 준수해야 하는 프로토콜입니다.
protocol TagConverting: Sendable {
    /// 처리할 HTML 태그의 이름입니다 (예: "h1", "p").
    var tagName: String { get }
    
    /// 주어진 `Element`를 Markdown 문자열로 변환합니다.
    /// - Parameter element: 변환할 SwiftSoup의 `Element`
    /// - Returns: 변환된 Markdown 문자열
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String
}

// MARK: - Concrete Tag Converters

struct H1Converter: TagConverting {
    let tagName = "h1"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "# " + (try element.text()) + "\n\n"
    }
}

struct H2Converter: TagConverting {
    let tagName = "h2"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "## " + (try element.text()) + "\n\n"
    }
}

struct H3Converter: TagConverting {
    let tagName = "h3"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "### " + (try element.text()) + "\n\n"
    }
}

struct H4Converter: TagConverting {
    let tagName = "h4"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "#### " + (try element.text()) + "\n\n"
    }
}

struct H5Converter: TagConverting {
    let tagName = "h5"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "##### " + (try element.text()) + "\n\n"
    }
}

struct H6Converter: TagConverting {
    let tagName = "h6"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "###### " + (try element.text()) + "\n\n"
    }
}

struct ParagraphConverter: TagConverting {
    let tagName = "p"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        // 내부 자식 노드들을 재귀적으로 변환하여 링크, 강조 등을 올바르게 처리합니다.
        try converter.convertChildren(of: element) + "\n\n"
    }
}

struct UnorderedListConverter: TagConverting {
    let tagName = "ul"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        var text = ""
        for li in try element.select("li") {
            // 각 리스트 아이템의 자식 노드를 재귀적으로 변환합니다.
            text += "- " + (try converter.convertChildren(of: li)) + "\n"
        }
        return text + "\n"
    }
}

struct OrderedListConverter: TagConverting {
    let tagName = "ol"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        var text = ""
        var count = 1
        for li in try element.select("li") {
            // 각 리스트 아이템의 자식 노드를 재귀적으로 변환합니다.
            text += "\(count). " + (try converter.convertChildren(of: li)) + "\n"
            count += 1
        }
        return text + "\n"
    }
}

struct LinkConverter: TagConverting {
    let tagName = "a"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "[" + (try element.text()) + "](" + (try element.attr("href")) + ")"
    }
}

struct ImageConverter: TagConverting {
    let tagName = "img"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "![" + (try element.attr("alt")) + "](" + (try element.attr("src")) + ")"
    }
}

struct InlineCodeConverter: TagConverting {
    let tagName = "code"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        // 'pre > code' 블록은 PreformattedTextConverter가 처리하므로, 여기서는 인라인 코드만 처리합니다.
        if let parent = element.parent(), parent.tagName() == "pre" {
            return "" // 부모(pre)에서 처리했으므로 빈 문자열 반환
        } else {
            return "`" + (try element.text()) + "`"
        }
    }
}

struct PreformattedTextConverter: TagConverting {
    let tagName = "pre"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        if let code = try element.select("code").first() {
            let language = try code.attr("class").replacingOccurrences(of: "language-", with: "")
            return "```\(language)\n" + (try code.text()) + "\n```\n\n"
        } else {
            return "```\n" + (try element.text()) + "\n```\n\n"
        }
    }
}

struct BlockquoteConverter: TagConverting {
    let tagName = "blockquote"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        // 블록 인용 내부의 복잡한 구조를 처리하기 위해 자식 노드를 재귀적으로 변환합니다.
        "> " + (try converter.convertChildren(of: element)).replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
    }
}

struct HorizontalRuleConverter: TagConverting {
    let tagName = "hr"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        "---\n\n"
    }
}

/// 기본(Default) 변환 전략으로, 등록되지 않은 태그를 처리합니다.
/// 자식 노드들을 재귀적으로 탐색하여 내부의 텍스트나 변환 가능한 태그들을 처리합니다.
struct DefaultTagConverter: Sendable {
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> String {
        try converter.convertChildren(of: element)
    }
}
