// Sources/Dendrite/Core/DocumentMetadata.swift

import Foundation

// MARK: - Document Metadata

/// 문서에서 추출된, 변경 불가능한 메타데이터를 담는 구조체
@frozen
public struct DocumentMetadata: @unchecked Sendable {
    
    // MARK: - Core Properties
    
    public let title: String?
    public let author: String?
    public let description: String?
    public let keywords: Set<String>
    public let creationDate: Date?
    public let modificationDate: Date?
    public let links: Set<URL>
    public let sourceDetails: SourceSpecificMetadata?
    
    // MARK: - Extended Properties
    
    public let language: String?
    public let mimeType: String?
    public let fileSize: Int?
    public let checksum: String?
    
    // MARK: - Initialization
    
    public init(
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        keywords: Set<String> = [],
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        links: Set<URL> = [],
        sourceDetails: SourceSpecificMetadata? = nil,
        language: String? = nil,
        mimeType: String? = nil,
        fileSize: Int? = nil,
        checksum: String? = nil
    ) {
        self.title = title
        self.author = author
        self.description = description
        self.keywords = keywords
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.links = links
        self.sourceDetails = sourceDetails
        self.language = language
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.checksum = checksum
    }
    
    // MARK: - Computed Properties
    
    public var isValid: Bool {
        if let title = title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if let fileSize = fileSize, fileSize < 0 { return false }
        return true
    }
    
    public var richnessScore: Double {
        var score = 0.0
        let maxScore = 8.0
        if title != nil { score += 1.0 }
        if author != nil { score += 1.0 }
        if description != nil { score += 1.0 }
        if !keywords.isEmpty { score += 1.0 }
        if creationDate != nil { score += 1.0 }
        if !links.isEmpty { score += 1.0 }
        if language != nil { score += 1.0 }
        if sourceDetails != nil { score += 1.0 }
        return score / maxScore
    }
}

// MARK: - Conformances

extension DocumentMetadata: Hashable {
    public static func == (lhs: DocumentMetadata, rhs: DocumentMetadata) -> Bool {
        return lhs.title == rhs.title &&
        lhs.author == rhs.author &&
        lhs.description == rhs.description &&
        lhs.keywords == rhs.keywords &&
        lhs.creationDate == rhs.creationDate &&
        lhs.modificationDate == rhs.modificationDate &&
        lhs.links == rhs.links &&
        lhs.language == rhs.language &&
        lhs.mimeType == rhs.mimeType &&
        lhs.fileSize == rhs.fileSize &&
        lhs.checksum == rhs.checksum
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(author)
        hasher.combine(description)
        hasher.combine(keywords)
        hasher.combine(creationDate)
        hasher.combine(modificationDate)
        hasher.combine(links)
        hasher.combine(language)
        hasher.combine(mimeType)
        hasher.combine(fileSize)
        hasher.combine(checksum)
    }
}

extension DocumentMetadata: Codable { }

// MARK: - Source-Specific Metadata

public enum SourceSpecificMetadata: @unchecked Sendable {
    case markdown(MarkdownMetadata)
    case html(HTMLMetadata)
    case pdf(PDFMetadata)
    case plainText(PlainTextMetadata)
    
    @frozen public struct MarkdownMetadata: Hashable, Codable, @unchecked Sendable {
        public let outline: [OutlineItem]
        public let tables: [TableMetadata]
        public let codeBlocks: [CodeBlockMetadata]
        public let frontMatter: [String: String]
    }
    @frozen public struct HTMLMetadata: Hashable, Codable, @unchecked Sendable {
        public let metaTags: [String: String]
        public let links: Set<URL>
        public let images: [ImageMetadata]
        public let scripts: [ScriptMetadata]
    }
    @frozen public struct PDFMetadata: Hashable, Codable, @unchecked Sendable {
        public let pageCount: Int
        public let bookmarks: [BookmarkMetadata]
        public let annotations: [AnnotationMetadata]
        public let producer: String?
        public let creator: String?
    }
    @frozen public struct PlainTextMetadata: Hashable, Codable, @unchecked Sendable {
        public let encoding: String
        public let lineEnding: LineEnding
        public let lineCount: Int
        public enum LineEnding: String, Codable, CaseIterable {
            case lf = "\n"
            case crlf = "\r\n"
            case cr = "\r"
        }
    }
}

// MARK: - SourceSpecificMetadata Conformances

extension SourceSpecificMetadata: Hashable {
    public static func == (lhs: SourceSpecificMetadata, rhs: SourceSpecificMetadata) -> Bool {
        switch (lhs, rhs) {
        case (.markdown(let l), .markdown(let r)):
            return l == r
        case (.html(let l), .html(let r)):
            return l == r
        case (.pdf(let l), .pdf(let r)):
            return l == r
        case (.plainText(let l), .plainText(let r)):
            return l == r
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .markdown(let data): hasher.combine(data)
        case .html(let data): hasher.combine(data)
        case .pdf(let data): hasher.combine(data)
        case .plainText(let data): hasher.combine(data)
        }
    }
}

extension SourceSpecificMetadata: Codable {
    private enum CodingKeys: String, CodingKey { case type, data }
    private enum MetadataType: String, Codable { case markdown, html, pdf, plainText }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MetadataType.self, forKey: .type)
        switch type {
        case .markdown:
            self = .markdown(try container.decode(MarkdownMetadata.self, forKey: .data))
        case .html:
            self = .html(try container.decode(HTMLMetadata.self, forKey: .data))
        case .pdf:
            self = .pdf(try container.decode(PDFMetadata.self, forKey: .data))
        case .plainText:
            self = .plainText(try container.decode(PlainTextMetadata.self, forKey: .data))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .markdown(let data):
            try container.encode(MetadataType.markdown, forKey: .type);
            try container.encode(data, forKey: .data)
        case .html(let data):
            try container.encode(MetadataType.html, forKey: .type);
            try container.encode(data, forKey: .data)
        case .pdf(let data):
            try container.encode(MetadataType.pdf, forKey: .type);
            try container.encode(data, forKey: .data)
        case .plainText(let data):
            try container.encode(MetadataType.plainText, forKey: .type);
            try container.encode(data, forKey: .data)
        }
    }
}


// MARK: - Supporting Metadata Types

@frozen public struct OutlineItem: Hashable, Codable, @unchecked Sendable { public let level: Int; public let title: String; public let anchor: String? }
@frozen public struct TableMetadata: Hashable, Codable, @unchecked Sendable { public let caption: String?; public let headers: [String]; public let rowCount: Int; public let columnCount: Int }
@frozen public struct CodeBlockMetadata: Hashable, Codable, @unchecked Sendable { public let language: String?; public let lineCount: Int; public let hasHighlighting: Bool }
@frozen public struct ImageMetadata: Hashable, Codable, @unchecked Sendable { public let url: URL; public let altText: String?; public let width: Int?; public let height: Int? }
@frozen public struct ScriptMetadata: Hashable, Codable, @unchecked Sendable { public let source: URL?; public let type: String; public let isAsync: Bool }
@frozen public struct BookmarkMetadata: Hashable, Codable, @unchecked Sendable { public let title: String; public let page: Int; public let level: Int }
@frozen public struct AnnotationMetadata: Hashable, Codable, @unchecked Sendable { public let type: AnnotationType; public let page: Int; public let content: String; public enum AnnotationType: String, Codable, CaseIterable { case highlight, note, bookmark, link } }


// MARK: - Builder

public final class DocumentMetadataBuilder {
    private var title: String?
    private var author: String?
    private var description: String?
    private var keywords: Set<String> = []
    private var creationDate: Date?
    private var modificationDate: Date?
    private var links: Set<URL> = []
    private var sourceDetails: SourceSpecificMetadata?
    private var language: String?
    private var mimeType: String?
    private var fileSize: Int?
    private var checksum: String?
    
    public init() {}
    
    @discardableResult public func title(_ title: String?) -> Self { self.title = title; return self }
    @discardableResult public func author(_ author: String?) -> Self { self.author = author; return self }
    @discardableResult public func description(_ description: String?) -> Self { self.description = description; return self }
    @discardableResult public func keywords(_ keywords: Set<String>?) -> Self { if let k = keywords { self.keywords = k }; return self }
    @discardableResult public func addKeyword(_ keyword: String) -> Self { self.keywords.insert(keyword); return self }
    @discardableResult public func creationDate(_ date: Date?) -> Self { self.creationDate = date; return self }
    @discardableResult public func modificationDate(_ date: Date?) -> Self { self.modificationDate = date; return self }
    @discardableResult public func links(_ links: Set<URL>?) -> Self { if let l = links { self.links = l }; return self }
    @discardableResult public func addLink(_ link: URL) -> Self { self.links.insert(link); return self }
    @discardableResult public func sourceDetails(_ details: SourceSpecificMetadata?) -> Self { self.sourceDetails = details; return self }
    @discardableResult public func language(_ language: String?) -> Self { self.language = language; return self }
    @discardableResult public func mimeType(_ mimeType: String?) -> Self { self.mimeType = mimeType; return self }
    @discardableResult public func fileSize(_ size: Int?) -> Self { self.fileSize = size; return self }
    @discardableResult public func checksum(_ checksum: String?) -> Self { self.checksum = checksum; return self }
    
    public func build() -> DocumentMetadata {
        return DocumentMetadata(title: title, author: author, description: description, keywords: keywords, creationDate: creationDate, modificationDate: modificationDate, links: links, sourceDetails: sourceDetails, language: language, mimeType: mimeType, fileSize: fileSize, checksum: checksum)
    }
}
