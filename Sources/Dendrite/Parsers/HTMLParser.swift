// Sources/Dendrite/Parsers/HTMLParser.swift

import Foundation
import UniformTypeIdentifiers
import SwiftSoup

/// HTML 파일을 파싱하여 `ParsedDocument`를 생성하는 파서입니다.
struct HTMLParser: ParserProtocol {
    
    var supportedTypes: [UTType] {
        [.html]
    }
    
    func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        do {
            let markdownContent = try MarkdownFromHTMLConverter().convert(htmlString)
            
            // HTML에서 메타데이터 추출
            let title = try? HTMLMetadataExtractor.extractTitle(from: htmlString)
            let links = try? HTMLMetadataExtractor.extractLinks(from: htmlString)
            
            var metadata = DocumentMetadata()
            metadata.title = title
            metadata.links = links
            metadata.sourceDetails = .html(DocumentMetadata.HTMLMetadata())
            
            return ParsedDocument(content: markdownContent, metadata: metadata)
        } catch {
            throw DendriteError.parsingFailed(parserName: "HTMLParser", underlyingError: error)
        }
    }
}

/// HTML에서 메타데이터를 추출하는 유틸리티입니다.
struct HTMLMetadataExtractor {
    static func extractTitle(from html: String) throws -> String? {
        let doc = try SwiftSoup.parse(html)
        return try doc.title()
    }
    
    static func extractLinks(from html: String) throws -> [String]? {
        let doc = try SwiftSoup.parse(html)
        let links = try doc.select("a[href]").map { try $0.attr("href") }
        return links.isEmpty ? nil : links
    }
}
