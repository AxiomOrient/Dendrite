// Sources/Dendrite/Core/Tokenizer.swift

import Foundation
import NaturalLanguage

// MARK: - Tokenizer Protocol

/// 토큰화 작업을 추상화한 프로토콜
public protocol Tokenizer: Sendable {
    /// 텍스트의 토큰 수를 계산합니다
    func countTokens(in text: String) async -> TokenCount
    
    /// 텍스트를 지정된 최대 토큰 수로 분할합니다
    func split(text: String, maxTokens: Int, by unit: NLTokenUnit) async -> [String]
    
    /// 토큰화 모델의 정보를 반환합니다
    var modelInfo: TokenizerModelInfo { get }
}

/// 토큰화 모델 정보
public struct TokenizerModelInfo: Sendable {
    public let name: String
    public let maxContextLength: Int
    public let averageTokensPerWord: Double
    
    public init(name: String, maxContextLength: Int, averageTokensPerWord: Double) {
        self.name = name
        self.maxContextLength = maxContextLength
        self.averageTokensPerWord = averageTokensPerWord
    }
}
