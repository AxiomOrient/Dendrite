// Sources/Dendrite/Converters/MarkdownFromHTMLConverter.swift

import Foundation
import SwiftSoup

/// HTML 문자열을 Markdown으로 변환하는 변환기입니다.
///
/// 내부적으로 전략 패턴(Strategy Pattern)을 사용하여 각 HTML 태그를 처리합니다.
/// 이를 통해 새로운 태그에 대한 변환 규칙을 기존 코드 수정 없이 추가할 수 있습니다.
struct MarkdownFromHTMLConverter: ConverterProtocol {
    typealias Input = String
    typealias Output = String
    
    /// 태그 이름을 키로, 변환 전략을 값으로 갖는 딕셔너리입니다.
    private let tagConverters: [String: TagConverting]
    
    /// 등록되지 않은 태그를 처리하는 기본 변환기입니다.
    private let defaultConverter = DefaultTagConverter()

    init() {
        // 지원하는 모든 변환 전략 객체를 등록합니다.
        // 새로운 태그를 지원하려면 이 배열에 새로운 전략 객체를 추가하기만 하면 됩니다.
        let strategies: [TagConverting] = [
            H1Converter(), H2Converter(), H3Converter(), H4Converter(), H5Converter(), H6Converter(),
            ParagraphConverter(),
            UnorderedListConverter(), OrderedListConverter(),
            LinkConverter(), ImageConverter(),
            InlineCodeConverter(), PreformattedTextConverter(),
            BlockquoteConverter(),
            HorizontalRuleConverter()
        ]
        
        // 빠른 조회를 위해 딕셔너리로 변환합니다.
        self.tagConverters = Dictionary(uniqueKeysWithValues: strategies.map { ($0.tagName, $0) })
    }

    /// HTML 문자열을 받아 Markdown으로 변환합니다.
    /// - Parameter html: 변환할 HTML 문자열
    /// - Returns: 변환된 Markdown 문자열
    func convert(_ html: String) throws -> String {
        let doc = try SwiftSoup.parse(html)
        var markdown = ""
        
        // body의 자식 노드들을 순회하며 변환을 시작합니다.
        if let body = doc.body() {
            markdown = try convertChildren(of: body)
        }
        
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 개별 `Node`를 Markdown 문자열로 변환합니다. `Element`와 `TextNode`를 모두 처리합니다.
    private func convert(node: Node) throws -> String {
        if let textNode = node as? TextNode {
            return textNode.text()
        }
        
        if let element = node as? Element {
            // 등록된 전략을 찾아 변환을 위임합니다.
            if let converter = tagConverters[element.tagName()] {
                return try converter.convert(element: element, converter: self)
            } else {
                // 등록된 전략이 없으면 기본 전략을 사용합니다.
                return try defaultConverter.convert(element: element, converter: self)
            }
        }
        return ""
    }
    
    /// 특정 `Element`의 모든 자식 노드를 순회하며 변환하고, 그 결과를 하나의 문자열로 합칩니다.
    /// 이 메서드는 public으로 노출되지 않지만, `TagConverting` 전략들이 재귀적 변환을 위해 호출할 수 있습니다.
    func convertChildren(of element: Element) throws -> String {
        var result = ""
        for childNode in element.getChildNodes() {
            result += try convert(node: childNode)
        }
        return result
    }
}
