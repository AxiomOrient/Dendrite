// Sources/Dendrite/Converters/MarkdownFromHTMLConverter.swift

import Foundation
import SwiftSoup

/// HTML 문자열을 `SemanticNode` 트리로 변환하는 변환기입니다.
///
/// 내부적으로 전략 패턴(Strategy Pattern)을 사용하여 각 HTML 태그를 처리합니다.
/// 이를 통해 새로운 태그에 대한 변환 규칙을 기존 코드 수정 없이 추가할 수 있습니다.
struct MarkdownFromHTMLConverter {
    
    /// 태그 이름을 키로, 변환 전략을 값으로 갖는 딕셔너리입니다.
    private let tagConverters: [String: TagConverting]
    
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
            HorizontalRuleConverter(),
            TableConverter(),
            StrongConverter(),
            EmphasisConverter()
        ]
        
        // 빠른 조회를 위해 딕셔너리로 변환합니다.
        self.tagConverters = Dictionary(uniqueKeysWithValues: strategies.map { ($0.tagName, $0) })
    }
    
    /// HTML 문자열을 받아 `SemanticNode` 배열로 변환합니다.
    /// - Parameter html: 변환할 HTML 문자열
    /// - Returns: 변환된 `SemanticNode`의 배열
    func convert(_ html: String) throws -> [SemanticNode] {
        let doc = try SwiftSoup.parse(html)
        guard let body = doc.body() else { return [] }
        return try convertChildren(of: body)
    }
    
    /// 특정 `Element`의 모든 자식 노드를 순회하며 변환하고, 그 결과를 `SemanticNode` 배열로 합칩니다.
    /// `flatMap`을 사용하여 각 자식 노드 변환 결과(배열)를 하나의 배열로 평탄화합니다.
    func convertChildren(of element: Element) throws -> [SemanticNode] {
        return try element.getChildNodes().flatMap { try self.convert(node: $0) }
    }
    
    /// 개별 `Node`를 `SemanticNode` 배열로 변환합니다. `Element`와 `TextNode`를 모두 처리합니다.
    /// - Parameter node: 변환할 SwiftSoup의 `Node`
    /// - Returns: 변환된 `SemanticNode`의 배열. 알 수 없는 태그의 경우, 그 자식들을 변환한 결과가 반환됩니다.
    private func convert(node: Node) throws -> [SemanticNode] {
        // 1. 텍스트 노드 처리
        if let textNode = node as? TextNode {
            let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? [] : [.text(text)]
        }
        
        // 2. 엘리먼트 노드 처리
        guard let element = node as? Element else {
            return []
        }
        
        // 3. 등록된 변환기가 있는 경우, 해당 변환기 사용
        if let converter = tagConverters[element.tagName()] {
            // 변환기가 단일 노드를 반환하므로, 배열로 감싸서 반환
            if let semanticNode = try converter.convert(element: element, converter: self) {
                return [semanticNode]
            }
            return []
        }
        
        // 4. 등록된 변환기가 없는 경우 (예: <div>, <span> 등)
        //    해당 태그는 무시하고, 자식 노드들을 재귀적으로 변환하여 반환
        return try convertChildren(of: element)
    }
}
