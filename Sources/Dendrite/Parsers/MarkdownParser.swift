// Sources/Dendrite/Parsers/MarkdownParser.swift

import Foundation
import Markdown
import UniformTypeIdentifiers

/// 통합된 `DocumentMetadata` 구조에 맞춰 `swift-markdown` AST를 직접 순회하는 지능형 파서입니다.
public final class MarkdownParser: ParserProtocol, @unchecked Sendable {
    
    public let supportedTypes: [UTType] = [UTType("net.daringfireball.markdown") ?? .plainText]
    
    public func parse(data: Data, type: UTType, metadataBuilder: DocumentMetadataBuilder) async throws -> (nodes: [SemanticNode], metadata: DocumentMetadata) {
        guard let markdownText = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        let (frontMatterString, contentString) = extractFrontMatter(from: markdownText)
        let preprocessedMatter = preprocessFrontMatter(frontMatterString)
        let frontMatterData = parseFrontMatter(preprocessedMatter)
        
        let document = Document(parsing: contentString)
        let processor = ASTProcessor(frontMatter: frontMatterData, metadataBuilder: metadataBuilder)
        let (nodes, metadata) = processor.process(document)
        
        return (nodes, metadata)
    }
    
    /// YAML Front Matter 블록을 추출하고, 나머지 콘텐츠를 반환합니다.
    private func extractFrontMatter(from text: String) -> (matter: String, content: String) {
        guard let regex = try? NSRegularExpression(pattern: #"^---\s*\n([\s\S]*?)\s*\n---"#, options: [.dotMatchesLineSeparators]) else {
            return ("", text)
        }
        
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsrange),
              match.numberOfRanges >= 2,
              let frontMatterRange = Range(match.range(at: 1), in: text),
              let blockRange = Range(match.range(at: 0), in: text) else {
            return ("", text)
        }
        
        let matter = String(text[frontMatterRange])
        let content = String(text[blockRange.upperBound...])
        return (matter, content)
    }
    
    /// 일반적인 YAML 오류(예: 따옴표 없는 문자열)를 수정하는 전처리 단계입니다.
    private func preprocessFrontMatter(_ matter: String) -> String {
        return matter.split(whereSeparator: \.isNewline).map { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            // 키: 값 형식이며, 값이 특수문자로 시작하지 않는 경우 따옴표 추가
            let parts = trimmedLine.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return String(line) }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            if !value.isEmpty && !value.hasPrefix("[") && !value.hasPrefix("{") && !value.hasPrefix("'") && !value.hasPrefix("\"") && !value.hasPrefix("-") {
                return "\(key): \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return String(line)
        }.joined(separator: "\n")
    }
    
    /// 다양한 형식의 날짜 문자열을 Date 객체로 정규화합니다.
    private func normalizeDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "")
        
        // ISO 8601 형식을 가장 먼저 시도
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withFullDate]
        if let date = isoFormatter.date(from: trimmed) { return date }
        
        // YYYY-MM-DD 형식
        let ymdFormatter = DateFormatter()
        ymdFormatter.dateFormat = "yyyy-MM-dd"
        if let date = ymdFormatter.date(from: trimmed) { return date }
        
        // 기타 일반적인 형식들 (예: DD-MM-YY)
        let dmyFormatter = DateFormatter()
        dmyFormatter.dateFormat = "dd-MM-yy"
        if let date = dmyFormatter.date(from: trimmed) { return date }
        
        dmyFormatter.dateFormat = "dd/MM/yy"
        if let date = dmyFormatter.date(from: trimmed) { return date }
        
        dmyFormatter.dateFormat = "dd.MM.yy"
        if let date = dmyFormatter.date(from: trimmed) { return date }
        
        return nil
    }
    
    /// Front Matter 문자열을 파싱하여 구조화된 데이터를 반환합니다.
    private func parseFrontMatter(_ matter: String) -> FrontMatterData {
        var properties: [String: String] = [:]
        var keywords: [String] = []
        var creationDate: Date?
        var modificationDate: Date?
        
        let lines = matter.split(whereSeparator: \.isNewline)
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            
            let key = parts[0].lowercased()
            let value = String(parts[1])
            
            switch key {
            case "keywords":
                keywords = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "date", "creationdate":
                creationDate = normalizeDate(from: value)
            case "modificationdate":
                modificationDate = normalizeDate(from: value)
            default:
                properties[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        
        return FrontMatterData(
            properties: properties,
            keywords: keywords,
            creationDate: creationDate,
            modificationDate: modificationDate
        )
    }
}

// MARK: - Supporting Types

private struct FrontMatterData: Sendable {
    let properties: [String: String]
    let keywords: [String]
    let creationDate: Date?
    let modificationDate: Date?
    
    var title: String? { properties["title"] }
    var author: String? { properties["author"] }
    var description: String? { properties["description"] }
    
    var asDictionary: [String: String] {
        var dict = properties
        if !keywords.isEmpty {
            dict["keywords"] = keywords.joined(separator: ", ")
        }
        return dict
    }
}

// MARK: - ASTProcessor

private final class ASTProcessor {
    private let frontMatter: FrontMatterData
    private let metadataBuilder: DocumentMetadataBuilder
    
    private var links: Set<URL> = []
    private var outline: [OutlineItem] = []
    private var tables: [TableMetadata] = []
    private var codeBlocks: [CodeBlockMetadata] = []
    
    init(frontMatter: FrontMatterData, metadataBuilder: DocumentMetadataBuilder) {
        self.frontMatter = frontMatter
        self.metadataBuilder = metadataBuilder
    }
    
    func process(_ document: Document) -> (nodes: [SemanticNode], metadata: DocumentMetadata) {
        let nodes = processChildren(Array(document.children))
        
        let markdownMetadata = SourceSpecificMetadata.MarkdownMetadata(
            outline: outline,
            tables: tables,
            codeBlocks: codeBlocks,
            frontMatter: frontMatter.asDictionary
        )
        
        let metadata = metadataBuilder
            .title(frontMatter.title ?? outline.first?.title)
            .author(frontMatter.author)
            .description(frontMatter.description)
            .keywords(Set(frontMatter.keywords))
            .creationDate(frontMatter.creationDate)
            .modificationDate(frontMatter.modificationDate)
            .links(links)
            .sourceDetails(.markdown(markdownMetadata))
            .build()
        
        return (nodes, metadata)
    }
    
    private func processChildren(_ children: [any Markup]) -> [SemanticNode] {
        children.compactMap(visit)
    }
    
    private func visit(_ markup: Markup) -> SemanticNode? {
        let range = convertSourceRange(from: markup)
        
        switch markup {
        case let heading as Heading: return processHeading(heading, range: range)
        case let paragraph as Paragraph: return .paragraph(children: processChildren(Array(paragraph.children)), range: range)
        case let blockquote as BlockQuote: return .blockquote(children: processChildren(Array(blockquote.children)), range: range)
        case let codeBlock as CodeBlock: return processCodeBlock(codeBlock, range: range)
        case let list as UnorderedList: return .list(isOrdered: false, items: processChildren(Array(list.listItems)), range: range)
        case let list as OrderedList: return .list(isOrdered: true, items: processChildren(Array(list.listItems)), range: range)
        case let listItem as ListItem: return .listItem(children: processChildren(Array(listItem.children)), range: range)
        case is ThematicBreak: return .thematicBreak(range: range)
        case let table as Table: return processTable(table, range: range)
        case let link as Link: return processLink(link)
        case let image as Image: return .image(source: image.source, alt: image.plainText)
        case let text as Text: return .text(text.string)
        case let emphasis as Emphasis: return .emphasis(children: processChildren(Array(emphasis.children)))
        case let strong as Strong: return .strong(children: processChildren(Array(strong.children)))
        case let inlineCode as InlineCode: return .inlineCode(inlineCode.code)
        default: return processGenericMarkup(markup, range: range)
        }
    }
    
    // MARK: - Specialized Processing Methods
    
    private func processHeading(_ heading: Heading, range: SourceRange?) -> SemanticNode {
        outline.append(OutlineItem(level: heading.level, title: heading.plainText, anchor: nil))
        return .heading(level: heading.level, text: heading.plainText, range: range)
    }
    
    private func processCodeBlock(_ codeBlock: CodeBlock, range: SourceRange?) -> SemanticNode {
        codeBlocks.append(CodeBlockMetadata(language: codeBlock.language, lineCount: codeBlock.code.components(separatedBy: .newlines).count, hasHighlighting: codeBlock.language != nil))
        return .codeBlock(language: codeBlock.language, code: codeBlock.code, range: range)
    }
    
    private func processTable(_ table: Table, range: SourceRange?) -> SemanticNode {
        let headers = Array(table.head.cells.map { $0.plainText })
        let rows = Array(table.body.rows.map { Array($0.cells.map { $0.plainText }) })
        
        tables.append(TableMetadata(caption: nil, headers: headers, rowCount: rows.count, columnCount: headers.count))
        
        return .table(caption: nil, headers: headers, rows: rows, range: range)
    }
    
    private func processLink(_ link: Link) -> SemanticNode {
        if let destination = link.destination, let url = URL(string: destination) { links.insert(url) }
        return .link(destination: link.destination, children: processChildren(Array(link.children)))
    }
    
    private func processGenericMarkup(_ markup: Markup, range: SourceRange?) -> SemanticNode? {
        let children = processChildren(Array(markup.children))
        switch children.count {
        case 0: return nil
        case 1: return children.first
        default: return .paragraph(children: children, range: range)
        }
    }
    
    // MARK: - Utility Methods
    
    private func convertSourceRange(from markup: Markup) -> SourceRange? {
        guard let sourceRange = markup.range else { return nil }
        
        let start = SourcePosition(line: sourceRange.lowerBound.line, column: sourceRange.lowerBound.column)
        let end = SourcePosition(line: sourceRange.upperBound.line, column: sourceRange.upperBound.column)
        return SourceRange(start: start, end: end)
    }
}
