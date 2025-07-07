// Sources/Dendrite/Core/ConverterProtocol.swift

import Foundation

/// 데이터 변환을 수행하는 객체가 준수해야 하는 프로토콜입니다.
///
/// `Sendable`을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public protocol ConverterProtocol: Sendable {
    
    /// 변환할 입력 데이터의 타입입니다.
    associatedtype Input
    
    /// 변환된 결과 데이터의 타입입니다.
    associatedtype Output
    
    /// 입력을 받아 결과로 변환합니다.
    /// - Parameter input: 변환할 `Input` 데이터
    /// - Returns: 변환된 `Output` 데이터
    /// - Throws: 변환 과정에서 발생한 에러
    func convert(_ input: Input) throws -> Output
}
