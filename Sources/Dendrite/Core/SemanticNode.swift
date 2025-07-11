// Sources/Dendrite/Core/SemanticNode.swift

import Foundation
import CryptoKit // CryptoKit 추가

// MARK: - Source Location Types

public struct SourcePosition: Sendable, Codable, Hashable {
    public let line: Int
    public let column: Int
}

public struct SourceRange: Sendable, Codable, Hashable {
    public let start: SourcePosition
    public let end: SourcePosition
}


// MARK: - Deterministic ID Generation Helper

/// 주어진 콘텐츠와 부모 ID를 기반으로 결정론적(Deterministic) ID를 생성합니다.
/// 동일한 입력에 대해 항상 동일한 ID를 반환하여 재현성을 보장합니다.
private func generateDeterministicId(content: String, parentId: String?) -> String {
    let combined = (parentId ?? "") + content
    let data = Data(combined.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

/// 문서의 의미론적 구조를 표현하는 표준화된 노드 타입입니다.
///
/// 모든 파서는 원본 문서를 이 `SemanticNode`의 트리 형태로 변환하는 것을 목표로 합니다.
/// 각 노드는 고유 ID를 가지므로, 문서 처리 파이프라인 전반에서 추적 및 참조가 가능합니다.
/// `Sendable`, `Hashable`, `Codable`을 준수하여 Swift의 모던 동시성 환경과 데이터 처리에 안전하게 사용될 수 있습니다.
public enum SemanticNode: Sendable, Hashable, Codable {
    
    case heading(level: Int, text: String, id: String, range: SourceRange? = nil)
    case paragraph(children: [SemanticNode], id: String, range: SourceRange? = nil)
    case list(isOrdered: Bool, items: [SemanticNode], id: String, range: SourceRange? = nil)
    case listItem(children: [SemanticNode], id: String, range: SourceRange? = nil)
    case blockquote(children: [SemanticNode], id: String, range: SourceRange? = nil)
    case codeBlock(language: String?, code: String, id: String, range: SourceRange? = nil)
    case table(caption: String?, headers: [String], rows: [[String]], id: String, range: SourceRange? = nil)
    case thematicBreak(id: String, range: SourceRange? = nil)
    
    // 인라인 요소들은 부모 블록 노드의 ID를 통해 간접적으로 식별됩니다.
    case link(destination: String?, children: [SemanticNode])
    case image(source: String?, alt: String)
    case text(String)
    case emphasis(children: [SemanticNode])
    case strong(children: [SemanticNode])
    case inlineCode(String)
    
    // MARK: - Initializers with Deterministic ID
    
    public static func heading(level: Int, text: String, parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        .heading(level: level, text: text, id: generateDeterministicId(content: text, parentId: parentId), range: range)
    }
    
    public static func paragraph(children: [SemanticNode], parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = children.map { $0.plainText }.joined()
        return .paragraph(children: children, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func list(isOrdered: Bool, items: [SemanticNode], parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = items.map { $0.plainText }.joined()
        return .list(isOrdered: isOrdered, items: items, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func listItem(children: [SemanticNode], parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = children.map { $0.plainText }.joined()
        return .listItem(children: children, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func blockquote(children: [SemanticNode], parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = children.map { $0.plainText }.joined()
        return .blockquote(children: children, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func codeBlock(language: String?, code: String, parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = (language ?? "") + code
        return .codeBlock(language: language, code: code, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func table(caption: String?, headers: [String], rows: [[String]], parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        let content = (caption ?? "") + headers.joined() + rows.flatMap { $0 }.joined()
        return .table(caption: caption, headers: headers, rows: rows, id: generateDeterministicId(content: content, parentId: parentId), range: range)
    }
    
    public static func thematicBreak(parentId: String? = nil, range: SourceRange? = nil) -> SemanticNode {
        .thematicBreak(id: generateDeterministicId(content: "thematicBreak", parentId: parentId), range: range)
    }
    
    /// 모든 구조적 노드의 고유 식별자를 반환합니다.
    public var id: String? {
        switch self {
        case .heading(_, _, let id, _),
                .paragraph(_, let id, _),
                .list(_, _, let id, _),
                .listItem(_, let id, _),
                .blockquote(_, let id, _),
                .codeBlock(_, _, let id, _),
                .table(_, _, _, let id, _),
                .thematicBreak(let id, _):
            return id
            // 인라인 요소들은 자체 ID를 가지지 않으므로 nil을 반환합니다.
        default:
            return nil
        }
    }
    
    /// 노드의 원본 소스 위치를 반환합니다. (선택적)
    public var range: SourceRange? {
        switch self {
        case .heading(_, _, _, let range),
                .paragraph(_, _, let range),
                .list(_, _, _, let range),
                .listItem(_, _, let range),
                .blockquote(_, _, let range),
                .codeBlock(_, _, _, let range),
                .table(_, _, _, _, let range),
                .thematicBreak(_, let range):
            return range
        default:
            return nil
        }
    }
    
    /// 노드 트리를 순수 텍스트 문자열로 변환합니다.
    public var plainText: String {
        switch self {
        case .heading(_, let text, _, _):
            return text
        case .paragraph(let children, _, _),
                .listItem(let children, _, _),
                .blockquote(let children, _, _),
                .emphasis(let children),
                .strong(let children):
            return children.map { $0.plainText }.joined()
        case .list(_, let items, _, _):
            return items.map { $0.plainText }.joined(separator: "\n")
        case .codeBlock(_, let code, _, _):
            return code
        case .table(_, let headers, let rows, _, _):
            let headerLine = headers.joined(separator: " | ")
            let rowLines = rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
            return headerLine + "\n" + rowLines
        case .thematicBreak:
            return "---"
        case .link(_, let children):
            return children.map { $0.plainText }.joined()
        case .image(_, let alt):
            return alt
        case .text(let text):
            return text
        case .inlineCode(let code):
            return code
        }
    }
    
    /// 노드 트리를 마크다운 문자열로 변환합니다.
    public var toMarkdown: String {
        switch self {
        case .heading(let level, let text, _, _):
            return String(repeating: "#", count: level) + " " + text
        case .paragraph(let children, _, _):
            return children.map { $0.toMarkdown }.joined() + "\n\n"
        case .list(let isOrdered, let items, _, _):
            return items.enumerated().map { (index, item) in
                let prefix = isOrdered ? "\(index + 1). " : "- "
                // listItem의 toMarkdown 결과가 여러 줄일 수 있으므로, 각 줄에 들여쓰기를 추가합니다.
                let itemMarkdown = item.toMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
                let indentedItem = itemMarkdown.replacingOccurrences(of: "\n", with: "\n  ")
                return prefix + indentedItem
            }.joined(separator: "\n") + "\n\n"
        case .listItem(let children, _, _):
            return children.map { $0.toMarkdown }.joined()
        case .blockquote(let children, _, _):
            // 블록 인용구 내부의 내용이 여러 줄일 경우를 대비하여 각 줄에 "> "를 붙입니다.
            let content = children.map { $0.toMarkdown }.joined()
            return content.split(separator: "\n").map { "> " + String($0) }.joined(separator: "\n") + "\n\n"
        case .codeBlock(let language, let code, _, _):
            let lang = language ?? ""
            return "```\(lang)\n\(code)\n```\n\n"
        case .table(let caption, let headers, let rows, _, _):
            var markdown = ""
            if let caption = caption, !caption.isEmpty {
                markdown += "> \(caption)\n\n" // 캡션과 테이블 사이에 한 줄 띄웁니다.
            }
            markdown += "| " + headers.joined(separator: " | ") + " |\n"
            markdown += "| " + headers.map { String(repeating: "-", count: $0.count) }.joined(separator: " | ") + " |\n"
            markdown += rows.map { "| " + $0.joined(separator: " | ") + " |" }.joined(separator: "\n") + "\n\n"
            return markdown
        case .thematicBreak:
            return "---" + "\n\n"
        case .link(let destination, let children):
            let text = children.map { $0.toMarkdown }.joined()
            return "[" + text + "](" + (destination ?? "") + ")"
        case .image(let source, let alt):
            return "![" + alt + "](" + (source ?? "") + ")"
        case .text(let text):
            return text
        case .emphasis(let children):
            return "*\(children.map { $0.toMarkdown }.joined())*"
        case .strong(let children):
            return "**\(children.map { $0.toMarkdown }.joined())**"
        case .inlineCode(let code):
            return "`\(code)`"
        }
    }
}

// MARK: - SemanticNode Extensions for Chunking

extension SemanticNode {
    /// 노드의 구조적 중요도를 계산합니다
    var structuralImportance: Double {
        switch self {
        case .heading(let level, _, _, _):
            return 1.0 - (Double(level - 1) * 0.15) // h1: 1.0, h2: 0.85, h3: 0.7, etc.
        case .table:
            return 0.9
        case .codeBlock:
            return 0.8
        case .list:
            return 0.7
        case .blockquote:
            return 0.6
        case .paragraph:
            return 0.5
        case .text:
            return 0.3
        case .link, .image, .emphasis, .strong, .inlineCode, .listItem, .thematicBreak:
            return 0.0 // 인라인 요소나 리스트 아이템, 구분선 등은 자체적인 구조적 중요도 낮음
        }
    }
    
    /// 노드가 컨텍스트 경계인지 확인합니다
    var isContextBoundary: Bool {
        switch self {
        case .heading, .table, .codeBlock, .thematicBreak:
            return true
        default:
            return false
        }
    }
    
    /// 노드가 특수 처리가 필요한지 확인합니다
    var requiresSpecialHandling: Bool {
        switch self {
        case .table, .codeBlock:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Convenience Accessors
    
    var asHeading: (level: Int, text: String, id: String)? {
        guard case .heading(let level, let text, let id, _) = self else { return nil }
        return (level, text, id)
    }
    
    var asTable: (caption: String?, headers: [String], rows: [[String]], id: String)? {
        guard case .table(let caption, let headers, let rows, let id, _) = self else { return nil }
        return (caption, headers, rows, id)
    }
    
    var asCodeBlock: (language: String?, code: String, id: String)? {
        guard case .codeBlock(let language, let code, let id, _) = self else { return nil }
        return (language, code, id)
    }
}
