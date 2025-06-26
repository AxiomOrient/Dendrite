// Sources/Dendrite/Parsers/ParserFactory.swift

import Foundation
import UniformTypeIdentifiers

/// `ParserProtocol`을 준수하는 파서 인스턴스를 생성하는 팩토리입니다.
///
/// `if-else` 분기문 대신, 주입된 파서 목록에서 주어진 타입을 처리할 수 있는 파서를 동적으로 찾아 반환합니다.
struct ParserFactory {
    
    /// 주어진 `UTType`과 사용 가능한 파서 목록을 기반으로 적절한 파서를 반환합니다.
    /// - Parameters:
    ///   - type: 파싱할 파일의 `UTType`
    ///   - availableParsers: `DendriteConfig`를 통해 주입된 파서의 배열
    /// - Returns: 해당 타입을 처리할 수 있는 `ParserProtocol`을 준수하는 객체. 지원하는 파서가 없는 경우 `nil`을 반환합니다.
    static func parser(for type: UTType, availableParsers: [ParserProtocol]) -> ParserProtocol? {
        // `first(where:)` 메서드를 사용하여 조건을 만족하는 첫 번째 파서를 찾습니다.
        // 이는 선언적이며 함수형 스타일을 따릅니다.
        // `availableParsers` 배열의 순서가 곧 파서의 우선순위가 됩니다.
        return availableParsers.first { $0.canParse(type: type) }
    }
}
