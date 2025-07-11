// Sources/Dendrite/Converters/TagConverters.swift

import Foundation
import SwiftSoup

// MARK: - Tag Converter Protocol

/// HTML 태그 변환 전략이 준수해야 하는 프로토콜입니다.
protocol TagConverting: Sendable {
    /// 처리할 HTML 태그의 이름입니다 (예: "h1", "p").
    var tagName: String { get }
    
    /// 주어진 `Element`를 `SemanticNode`로 변환합니다.
    /// - Parameter element: 변환할 SwiftSoup의 `Element`
    /// - Returns: 변환된 `SemanticNode`
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode?
}

// MARK: - Concrete Tag Converters

struct H1Converter: TagConverting {
    let tagName = "h1"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 1, text: try element.text())
    }
}

struct H2Converter: TagConverting {
    let tagName = "h2"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 2, text: try element.text())
    }
}

struct H3Converter: TagConverting {
    let tagName = "h3"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 3, text: try element.text())
    }
}

struct H4Converter: TagConverting {
    let tagName = "h4"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 4, text: try element.text())
    }
}

struct H5Converter: TagConverting {
    let tagName = "h5"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 5, text: try element.text())
    }
}

struct H6Converter: TagConverting {
    let tagName = "h6"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .heading(level: 6, text: try element.text())
    }
}

struct ParagraphConverter: TagConverting {
    let tagName = "p"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let children = try converter.convertChildren(of: element)
        return .paragraph(children: children)
    }
}

struct UnorderedListConverter: TagConverting {
    let tagName = "ul"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let items = try element.select("li").map { li -> SemanticNode in
            let children = try converter.convertChildren(of: li)
            return .listItem(children: children)
        }
        return .list(isOrdered: false, items: items)
    }
}

struct OrderedListConverter: TagConverting {
    let tagName = "ol"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let items = try element.select("li").map { li -> SemanticNode in
            let children = try converter.convertChildren(of: li)
            return .listItem(children: children)
        }
        return .list(isOrdered: true, items: items)
    }
}

struct LinkConverter: TagConverting {
    let tagName = "a"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let children = try converter.convertChildren(of: element)
        let href = try element.attr("href")
        let destination: String? = href.isEmpty ? nil : href
        return .link(destination: destination, children: children)
    }
}

struct ImageConverter: TagConverting {
    let tagName = "img"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let src = try element.attr("src")
        let source: String? = src.isEmpty ? nil : src
        let altText = try element.attr("alt")
        return .image(source: source, alt: altText)
    }
}

struct InlineCodeConverter: TagConverting {
    let tagName = "code"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        if let parent = element.parent(), parent.tagName() == "pre" {
            return nil // 부모(pre)에서 처리하므로 nil 반환
        } else {
            return .inlineCode(try element.text())
        }
    }
}

struct PreformattedTextConverter: TagConverting {
    let tagName = "pre"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        if let code = try element.select("code").first() {
            let language = try code.attr("class").replacingOccurrences(of: "language-", with: "")
            return .codeBlock(language: language, code: try code.text())
        } else {
            return .codeBlock(language: nil, code: try element.text())
        }
    }
}

struct BlockquoteConverter: TagConverting {
    let tagName = "blockquote"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let children = try converter.convertChildren(of: element)
        return .blockquote(children: children)
    }
}

struct HorizontalRuleConverter: TagConverting {
    let tagName = "hr"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        .thematicBreak()
    }
}

// --- 추가된 변환기들 ---

struct StrongConverter: TagConverting {
    let tagName = "strong"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let children = try converter.convertChildren(of: element)
        return .strong(children: children)
    }
}

struct EmphasisConverter: TagConverting {
    let tagName = "em"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let children = try converter.convertChildren(of: element)
        return .emphasis(children: children)
    }
}

struct TableConverter: TagConverting {
    let tagName = "table"
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> SemanticNode? {
        let caption = try? element.select("caption").first()?.text()
        
        // thead와 tbody에서 헤더와 행을 모두 고려
        let headers = try element.select("th").map { try $0.text() }
        let rows = try element.select("tr").compactMap { row -> [String]? in
            let cells = try row.select("td").map { try $0.text() }
            // 헤더 행(th만 있는 경우)은 row에서 제외
            return cells.isEmpty ? nil : cells
        }
        
        // 유효한 테이블인지 확인 (헤더나 내용이 있어야 함)
        guard !headers.isEmpty || !rows.isEmpty else { return nil }
        
        return .table(caption: caption, headers: headers, rows: rows)
    }
}

/// 기본(Default) 변환 전략으로, 등록되지 않은 태그를 처리합니다.
/// 자식 노드들을 재귀적으로 탐색하여 내부의 텍스트나 변환 가능한 태그들을 처리합니다.
struct DefaultTagConverter: Sendable {
    func convert(element: Element, converter: MarkdownFromHTMLConverter) throws -> [SemanticNode] {
        try converter.convertChildren(of: element)
    }
}
