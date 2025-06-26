// Sources/Dendrite/Parsers/ParserProtocol.swift

import Foundation
import UniformTypeIdentifiers

/// 모든 파서가 준수해야 하는 프로토콜입니다.
///
/// Sendable을 준수하여, 파서 인스턴스들이 동시성 환경에서 안전하게 전달될 수 있도록 보장합니다.
public protocol ParserProtocol: Sendable {
    
    /// 이 파서가 지원하는 `UTType`의 배열입니다.
    var supportedTypes: [UTType] { get }
    
    /// 주어진 데이터와 파일 타입을 파싱하여 `ParsedDocument` 객체를 반환합니다.
    /// - Parameters:
    ///   - data: 파싱할 파일의 원본 데이터
    ///   - type: 파일의 `UTType`
    /// - Returns: 파싱된 문서 객체
    /// - Throws: 파싱 과정에서 발생한 에러. 작업이 취소된 경우 `CancellationError`를 던집니다.
    func parse(data: Data, type: UTType) async throws -> ParsedDocument
    
    /// 이 파서가 주어진 `UTType`을 처리할 수 있는지 확인합니다.
    /// - Parameter type: 확인할 파일의 `UTType`
    /// - Returns: 처리 가능 여부를 나타내는 `Bool` 값
    func canParse(type: UTType) -> Bool
}

// MARK: - Default Implementation
public extension ParserProtocol {
    
    func canParse(type: UTType) -> Bool {
        supportedTypes.contains { type.conforms(to: $0) }
    }
}
