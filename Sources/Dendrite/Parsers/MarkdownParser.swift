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
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }

        try Task.checkCancellation()

        let document = Document(parsing: markdownString)

        // 1. 콘텐츠 추출: 내장된 `plainText` 속성을 사용할 수 없으므로, 직접 구현한 Walker를 사용합니다。
        var contentWalker = ContentExtractor()
        contentWalker.visit(document)
        let content = contentWalker.plainText

        // 2. 메타데이터 추출: 별도의 Walker를 사용하여 구조적 정보만 추출합니다。
        var metadataWalker = MetadataExtractor()
        metadataWalker.visit(document)
        var metadata = DocumentMetadata()
        metadata.title = metadataWalker.title
        metadata.links = metadataWalker.links.isEmpty ? nil : metadataWalker.links

        // Markdown 고유 메타데이터를 설정합니다.
        let mdMeta = DocumentMetadata.MarkdownMetadata(
            outline: metadataWalker.outline.isEmpty ? nil : metadataWalker.outline
        )
        metadata.sourceDetails = .markdown(mdMeta)

        return ParsedDocument(
            content: content,
            metadata: metadata
        )
    }
}

// MARK: - Private Extractors

private extension MarkdownParser {

    /// Markdown 문서에서 순수 텍스트 콘텐츠를 추출하는 Walker입니다.
    struct ContentExtractor: Markdown.MarkupWalker {
        var plainText: String = ""

        mutating func visitText(_ text: Text) {
            plainText.append(text.string)
        }

        mutating func visitParagraph(_ paragraph: Paragraph) {
            if !plainText.isEmpty && !plainText.hasSuffix("\n\n") {
                 plainText.append("\n\n")
            }
            descendInto(paragraph)
        }

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

        mutating func defaultVisit(_ markup: Markup) {
            descendInto(markup)
        }
    }

    /// Markdown 문서에서 구조적 메타데이터(제목, 개요, 링크)만 추출하는 Walker입니다.
    struct MetadataExtractor: MarkupWalker {
        private(set) var title: String? // 첫 H1을 제목으로 사용
        private(set) var outline: [String] = []
        private(set) var links: [String] = []

        mutating func visitHeading(_ heading: Heading) {
            if heading.level == 1 && title == nil { // 첫 H1을 제목으로 설정
                title = heading.plainText
            }
            outline.append(heading.plainText)
            descendInto(heading)
        }

        mutating func visitLink(_ link: Link) {
            if let destination = link.destination {
                links.append(destination)
            }
            descendInto(link)
        }

        mutating func defaultVisit(_ markup: Markup) {
            descendInto(markup)
        }
    }
}
