// Sources/Dendrite/Parsers/MarkdownParser.swift

import Foundation
import UniformTypeIdentifiers
import Markdown

/// `swift-markdown` 라이브러리를 기반으로 Markdown 문서를 파싱하여 구조적인 메타데이터까지 추출하는 파서입니다.
struct MarkdownParser: ParserProtocol {

    // MARK: - Properties

    public let supportedTypes: [UTType] = [
        UTType("net.daringfireball.markdown")
    ].compactMap { $0 }

    // MARK: - ParserProtocol Implementation

    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        guard let markdownString = String(data: data, encoding: .utf8) else {
            // UTF-8 변환 실패 시 구체적인 에러를 던집니다.
            let error = NSError(domain: "Dendrite.MarkdownParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "데이터를 UTF-8 문자열로 변환할 수 없습니다."])
            throw DendriteError.parsingFailed(parserName: "MarkdownParser", underlyingError: error)
        }
        
        try Task.checkCancellation()
        
        let document = Document(parsing: markdownString)
        let (content, metadata) = extractContentAndMetadata(from: document)
        
        // 여러 줄바꿈과 앞뒤 공백을 정리하여 가독성 있는 본문을 만듭니다.
        let cleanedContent = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            
        return ParsedDocument(
            content: cleanedContent,
            metadata: metadata
        )
    }
    
    // MARK: - Private Helper
    
    private func extractContentAndMetadata(from document: Document) -> (String, DocumentMetadata) {
        var walker = MarkupWalker()
        walker.visit(document)
        
        var metadata = DocumentMetadata()
        metadata.title = walker.title
        metadata.outline = walker.outline.isEmpty ? nil : walker.outline
        metadata.links = walker.links.isEmpty ? nil : walker.links
        
        return (walker.plainText, metadata)
    }
}

// MARK: - Private MarkupWalker

private extension MarkdownParser {
    
    struct MarkupWalker: Markdown.MarkupWalker {
        private(set) var title: String?
        private(set) var outline: [String] = []
        private(set) var links: [String] = []
        private(set) var plainText: String = ""

        mutating func visitHeading(_ heading: Heading) {
            let headingText = heading.plainText
            
            if heading.level == 1 && title == nil {
                title = headingText
            }
            outline.append(headingText)
            
            // --- FIX: 올바른 메소드 이름으로 자식 노드 순회를 계속하도록 명시적 호출 ---
            descendInto(heading)
        }
        
        mutating func visitLink(_ link: Link) {
            if let destination = link.destination {
                links.append(destination)
            }
            // --- FIX: 올바른 메소드 이름으로 자식 노드 순회를 계속하도록 명시적 호출 ---
            descendInto(link)
        }
        
        mutating func visitText(_ text: Text) {
            // 텍스트 노드를 만날 때마다 내용을 합칩니다.
            plainText.append(text.string)
        }
        
        mutating func visitParagraph(_ paragraph: Paragraph) {
            // 이전에 텍스트가 있었다면 단락 구분을 위해 줄바꿈을 추가합니다.
            if !plainText.isEmpty && !plainText.hasSuffix("\n\n") {
                 plainText.append("\n\n")
            }
            // --- FIX: 올바른 메소드 이름으로 자식 노드 순회를 계속하도록 명시적 호출 ---
            descendInto(paragraph)
        }
        
        // 다른 블록 요소들도 텍스트 추출을 위해 순회를 계속합니다.
        mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
            if !plainText.isEmpty && !plainText.hasSuffix("\n\n") {
                 plainText.append("\n\n")
            }
            descendInto(blockQuote)
        }

        mutating func visitListItem(_ listItem: ListItem) {
            if !plainText.isEmpty && !plainText.hasSuffix("\n") {
                 plainText.append("\n")
            }
            descendInto(listItem)
        }
        
        // defaultVisit을 구현하여 명시적으로 처리하지 않은 모든 요소에 대해 자식 순회를 보장합니다.
        mutating func defaultVisit(_ markup: Markup) {
            descendInto(markup)
        }
    }
}
