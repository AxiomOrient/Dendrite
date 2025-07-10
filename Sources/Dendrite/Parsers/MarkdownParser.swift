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
        
        var tableExtractor = TableExtractor()
        tableExtractor.visit(document)

        var metadata = DocumentMetadata()
        metadata.title = metadataWalker.title
        metadata.links = metadataWalker.links.isEmpty ? nil : metadataWalker.links

        // Markdown 고유 메타데이터를 설정합니다.
        let mdMeta = DocumentMetadata.MarkdownMetadata(
            outline: metadataWalker.outline.isEmpty ? nil : metadataWalker.outline,
            tables: tableExtractor.tables.isEmpty ? nil : tableExtractor.tables
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

        mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
            plainText.append("```\n")
            plainText.append(codeBlock.code)
            plainText.append("\n```\n\n")
        }

        mutating func visitInlineCode(_ inlineCode: InlineCode) {
            plainText.append("`")
            plainText.append(inlineCode.code)
            plainText.append("`")
        }
        
        // 테이블은 구조화된 데이터로 메타데이터에 저장되므로,
        // ContentExtractor에서는 텍스트로 포함하지 않습니다.
        mutating func visitTable(_ table: Table) {
            // Do nothing, as table content is extracted separately for metadata
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
    
    /// Markdown 문서에서 테이블 데이터를 추출하는 Walker입니다. (관용적 사용법 적용)
    struct TableExtractor: MarkupWalker {
        private(set) var tables: [DocumentMetadata.TableData] = []
        
        // 현재 파싱 중인 테이블의 상태를 저장하는 내부 변수
        private var currentHeaders: [String]?
        private var currentRows: [[String]]? = []
        private var currentRow: [String]?
        private var isInHeader = false

        // <table> 태그를 방문할 때 호출됨
        mutating func visitTable(_ table: Markdown.Table) {
            // 새 테이블 시작 시 상태 초기화
            currentHeaders = nil
            currentRows = []
            
            // 워커에게 자식 노드(Head, Body) 순회를 맡김
            descendInto(table)
            
            // 테이블 순회가 끝나면 완성된 데이터를 저장
            if let headers = currentHeaders, let rows = currentRows {
                tables.append(.init(headers: headers, rows: rows))
            }
            
            // 상태 변수 정리
            currentHeaders = nil
            currentRows = nil
        }

        // <thead> 태그를 방문할 때 호출됨
        mutating func visitTableHead(_ tableHead: Markdown.Table.Head) {
            isInHeader = true
            descendInto(tableHead) // 헤더 내부의 자식 노드(Row) 순회
            isInHeader = false
        }
        
        // <tbody> 태그를 방문할 때 호출됨
        mutating func visitTableBody(_ tableBody: Markdown.Table.Body) {
            descendInto(tableBody) // 본문 내부의 자식 노드(Row) 순회
        }

        // <tr> 태그를 방문할 때 호출됨
        mutating func visitTableRow(_ tableRow: Markdown.Table.Row) {
            currentRow = [] // 새 행 시작
            descendInto(tableRow) // 행 내부의 자식 노드(Cell) 순회
            
            if let row = currentRow {
                if isInHeader {
                    // 헤더 상태일 경우, 이 행을 헤더로 저장
                    currentHeaders = row
                } else {
                    // 본문 상태일 경우, 이 행을 본문 행 목록에 추가
                    currentRows?.append(row)
                }
            }
            currentRow = nil // 현재 행 처리 완료
        }

        // <td> 또는 <th> 태그를 방문할 때 호출됨
        mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) {
            // 셀의 순수 텍스트를 추출하여 현재 행에 추가
            currentRow?.append(tableCell.plainText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
