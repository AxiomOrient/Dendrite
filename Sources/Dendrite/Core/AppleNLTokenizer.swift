// Sources/Dendrite/Core/AppleNLTokenizer.swift

import Foundation
import NaturalLanguage

// MARK: - AppleNLTokenizer Implementation

/// Apple의 NaturalLanguage 프레임워크를 사용하여 텍스트의 토큰 수를 계산하고,
/// 지정된 의미 단위(Token Unit)에 따라 텍스트를 분할하는 구체적인 토크나이저 클래스입니다.
public final class AppleNLTokenizer: Tokenizer {
    
    // MARK: - Properties
    
    public let modelInfo: TokenizerModelInfo = TokenizerModelInfo(
        name: "AppleNLTokenizer",
        maxContextLength: 2048, // NLTokenizer의 일반적인 컨텍스트 길이 추정치
        averageTokensPerWord: 1.0 // 단어 단위 토큰화이므로 단어당 1토큰
    )
    
    // MARK: - Private Properties
    
    /// 토큰 계산을 위한 전용 액터로 동시성 안전성을 보장합니다.
    private let tokenizationActor = TokenizationActor()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 주어진 텍스트의 단어 토큰 수를 비동기적으로 계산하여 반환합니다.
    public func countTokens(in text: String) async -> TokenCount {
        guard !text.isEmpty else { return TokenCount(0) }
        
        let count = await tokenizationActor.countTokens(in: text)
        return TokenCount(count)
    }
    
    /// 주어진 텍스트를 지정된 의미 단위(`NLTokenUnit`)와 최대 토큰 수를 기준으로 비동기적으로 분할합니다.
    public func split(text: String, maxTokens: Int, by unit: NLTokenUnit) async -> [String] {
        guard maxTokens > 0 else { return [] }
        
        let totalTokens = await countTokens(in: text).value
        guard totalTokens > maxTokens else { return [text] }
        
        return await tokenizationActor.split(text: text, maxTokens: maxTokens, by: unit)
    }
}

// MARK: - TokenizationActor

/// 토큰화 작업을 안전하게 처리하는 전용 액터입니다.
/// Swift 6의 Actor 모델을 사용하여 race condition을 방지합니다.
private actor TokenizationActor {
    
    // MARK: - Token Counting
    
    /// 텍스트의 토큰 수를 계산합니다.
    func countTokens(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        
        return count
    }
    
    // MARK: - Text Splitting
    
    /// 텍스트를 지정된 단위로 분할합니다.
    func split(text: String, maxTokens: Int, by unit: NLTokenUnit) -> [String] {
        let segments = extractSegments(from: text, by: unit)
        
        var chunks: [String] = []
        var currentChunk = ""
        var currentTokens = 0
        
        for segment in segments {
            let segmentTokens = countTokens(in: segment)
            
            // 현재 청크에 추가할 수 있는지 확인
            if currentTokens + segmentTokens <= maxTokens {
                currentChunk += segment
                currentTokens += segmentTokens
            } else {
                // 현재 청크가 비어있지 않으면 저장
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                
                // 세그먼트가 너무 큰 경우 단어 단위로 분할
                if segmentTokens > maxTokens {
                    chunks.append(contentsOf: splitByWords(text: segment, maxTokens: maxTokens))
                    currentChunk = ""
                    currentTokens = 0
                } else {
                    currentChunk = segment
                    currentTokens = segmentTokens
                }
            }
        }
        
        // 마지막 청크 처리
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    // MARK: - Private Helper Methods
    
    /// 텍스트에서 지정된 단위로 세그먼트를 추출합니다.
    private func extractSegments(from text: String, by unit: NLTokenUnit) -> [String] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        
        var segments: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let segment = String(text[tokenRange])
            segments.append(segment)
            return true
        }
        
        return segments
    }
    
    /// 단어 단위로 텍스트를 분할합니다.
    private func splitByWords(text: String, maxTokens: Int) -> [String] {
        let words = extractSegments(from: text, by: .word)
        
        var chunks: [String] = []
        var currentChunk = ""
        var currentTokens = 0
        
        for word in words {
            let wordTokens = 1 // 단어 하나는 토큰 1개로 간주
            
            if currentTokens + wordTokens <= maxTokens {
                currentChunk += word
                currentTokens += wordTokens
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentChunk = word
                currentTokens = wordTokens
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks.filter { !$0.isEmpty }
    }
}

// MARK: - Extensions

extension AppleNLTokenizer {
    
    /// 편의를 위한 동기 버전의 토큰 계산 메서드입니다.
    /// 테스트나 간단한 용도로 사용할 수 있습니다.
    public func countTokensSync(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        
        return count
    }
}

// MARK: - Configuration

extension AppleNLTokenizer {
    
    /// 토크나이저 설정을 위한 구성 구조체입니다.
    public struct Configuration: Sendable {
        public let trimWhitespace: Bool
        public let filterEmptyChunks: Bool
        public let preserveFormatting: Bool
        
        public init(
            trimWhitespace: Bool = true,
            filterEmptyChunks: Bool = true,
            preserveFormatting: Bool = false
        ) {
            self.trimWhitespace = trimWhitespace
            self.filterEmptyChunks = filterEmptyChunks
            self.preserveFormatting = preserveFormatting
        }
        
        public static let `default` = Configuration()
    }
    
    /// 설정을 적용하여 텍스트를 분할합니다.
    public func split(
        text: String,
        maxTokens: Int,
        by unit: NLTokenUnit,
        configuration: Configuration = .default
    ) async -> [String] {
        let chunks = await split(text: text, maxTokens: maxTokens, by: unit)
        
        return chunks.compactMap { chunk in
            var processedChunk = chunk
            
            if configuration.trimWhitespace {
                processedChunk = processedChunk.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if configuration.filterEmptyChunks && processedChunk.isEmpty {
                return nil
            }
            
            return processedChunk
        }
    }
}
