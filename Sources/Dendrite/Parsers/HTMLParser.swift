// Sources/Dendrite/Parsers/HTMLParser.swift

import Foundation
import UniformTypeIdentifiers
import SwiftSoup

/// HTML 파일을 파싱하여 `ParsedDocument`를 생성하는 파서입니다.
struct HTMLParser: ParserProtocol {
    
    var supportedTypes: [UTType] {
        [.html]
    }
    
    func parse(data: Data, type: UTType, metadataBuilder: DocumentMetadataBuilder) async throws -> (nodes: [SemanticNode], metadata: DocumentMetadata) {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw DendriteError.decodingFailed(encoding: "UTF-8")
        }
        
        do {
            let doc = try SwiftSoup.parse(htmlString)
            let nodes = try MarkdownFromHTMLConverter().convert(htmlString)
            
            // HTML에서 메타데이터 추출하여 빌더에 추가
            try extractMetadata(from: doc, into: metadataBuilder)
            
            return (nodes: nodes, metadata: metadataBuilder.build())
        } catch {
            throw DendriteError.parsingFailed(parserName: "HTMLParser", underlyingError: error)
        }
    }
    
    private func extractMetadata(from doc: Document, into builder: DocumentMetadataBuilder) throws {
        builder.title(try? doc.title())
        
        let links = try? doc.select("a[href]").compactMap({ try? URL(string: $0.attr("href")) })
        builder.links(links.map { Set($0) } ?? [])
        
        var metaTags: [String: String] = [:]
        let metaTagElements = try doc.select("meta")
        for tag in metaTagElements {
            let name = try tag.attr("name").lowercased()
            let content = try tag.attr("content")
            
            guard !content.isEmpty else { continue }
            metaTags[name] = content
            
            switch name {
            case "author":
                builder.author(content)
            case "description":
                builder.description(content)
            case "keywords":
                let keywords = Set(content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                builder.keywords(keywords)
            default:
                break
            }
        }
        
        let imageElements = try doc.select("img")
        let images = imageElements.compactMap { element -> ImageMetadata? in
            guard let src = try? element.attr("src"), let url = URL(string: src) else { return nil }
            let alt = try? element.attr("alt")
            let widthString = try? element.attr("width")
            let heightString = try? element.attr("height")
            let width = Int(widthString ?? "")
            let height = Int(heightString ?? "")
            return ImageMetadata(url: url, altText: alt, width: width, height: height)
        }
        
        let scriptElements = try doc.select("script")
        let scripts = scriptElements.compactMap { element -> ScriptMetadata? in
            let src = try? element.attr("src")
            let url = src.flatMap { URL(string: $0) }
            let type = (try? element.attr("type")) ?? "text/javascript"
            let isAsync = element.hasAttr("async")
            return ScriptMetadata(source: url, type: type, isAsync: isAsync)
        }
        
        let htmlMetadata = SourceSpecificMetadata.HTMLMetadata(
            metaTags: metaTags,
            links: links.map { Set($0) } ?? [],
            images: images,
            scripts: scripts
        )
        
        builder.sourceDetails(.html(htmlMetadata))
    }
}
