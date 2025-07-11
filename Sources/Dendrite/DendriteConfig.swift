// Sources/Dendrite/DendriteConfig.swift

import Foundation
import UniformTypeIdentifiers
import NaturalLanguage

public struct DendriteConfig: Sendable {
    
    public var chunking: Chunking
    public let parsers: [any ParserProtocol]
    
    public init(
        chunking: Chunking = .default,
        customParsers: [any ParserProtocol]? = nil
    ) {
        self.chunking = chunking
        if let customParsers = customParsers {
            self.parsers = customParsers
        } else {
            self.parsers = [
                HTMLParser(),
                MarkdownParser(),
                PlainTextParser()
            ]
        }
    }
    
    public static let `default` = DendriteConfig()
    
    // MARK: - Nested Configurations
    
    /// 청킹 작업의 세부 설정을 담는 구조체
    public struct Chunking: Sendable {
        public let maxTokensPerChunk: Int
        public let minTokensPerChunk: Int
        public let overlapTokens: Int
        public let splitUnit: NLTokenUnit
        public let preserveContext: Bool
        public let qualityThreshold: Double
        public let enableSpecialHandling: Bool
        
        public init(
            maxTokensPerChunk: Int = 512,
            minTokensPerChunk: Int = 32,
            overlapTokens: Int = 32,
            splitUnit: NLTokenUnit = .sentence,
            preserveContext: Bool = true,
            qualityThreshold: Double = 0.7,
            enableSpecialHandling: Bool = true
        ) {
            self.maxTokensPerChunk = max(64, maxTokensPerChunk)
            self.minTokensPerChunk = max(16, min(minTokensPerChunk, maxTokensPerChunk / 4))
            self.overlapTokens = max(0, min(overlapTokens, maxTokensPerChunk / 4))
            self.splitUnit = splitUnit
            self.preserveContext = preserveContext
            self.qualityThreshold = max(0.0, min(1.0, qualityThreshold))
            self.enableSpecialHandling = enableSpecialHandling
        }
        
        public static let `default` = Chunking()
    }
}
