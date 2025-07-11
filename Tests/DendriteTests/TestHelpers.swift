// Tests/DendriteTests/TestHelpers.swift

import Foundation
import Testing // Import Testing framework

/// 테스트용 fixture 파일의 URL을 반환합니다.
/// - Parameter name: `Tests/DendriteTests/Resources` 폴더에 있는 파일의 이름 (확장자 포함)
/// - Returns: 파일의 전체 URL
/// - Throws: 파일 URL을 생성할 수 없는 경우 오류를 발생시킵니다.
func fixture(name: String) throws -> URL {
    let parts = name.split(separator: ".")
    guard parts.count > 1 else {
        Issue.record("Fixture 이름에는 확장자가 포함되어야 합니다: \(name)") // Use Issue.record
        throw FixtureError(path: name, message: "Fixture 이름에는 확장자가 포함되어야 합니다.")
    }
    let baseName = parts.dropLast().joined(separator: ".")
    let fileExtension = String(parts.last!)

    guard let resourceURL = Bundle.module.url(forResource: baseName, withExtension: fileExtension) else {
        Issue.record("번들에서 Fixture를 찾을 수 없습니다: \(name)") // Use Issue.record
        throw FixtureError(path: name, message: "번들에서 Fixture를 찾을 수 없습니다.")
    }
    return resourceURL
}

struct FixtureError: Error, CustomStringConvertible {
    let path: String
    let message: String
    var description: String { "Fixture 경로 오류: \(path). 원인: \(message)" }
}