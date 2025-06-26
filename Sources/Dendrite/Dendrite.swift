// Sources/Dendrite/Dendrite.swift

import Foundation
import UniformTypeIdentifiers

/// 다양한 형식의 문서를 파싱하여 일관된 `ParsedDocument`로 변환하는 라이브러리의 메인 진입점입니다.
public struct Dendrite {
    
    /// 지정된 URL의 파일을 파싱합니다.
    ///
    /// 이 정적 메서드는 URL로부터 비동기적으로 데이터를 읽고, 파일 확장자에 맞는 파서를 선택하여 파싱을 수행합니다.
    ///
    /// - Parameters:
    ///   - url: 파싱할 파일의 URL
    ///   - config: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `DendriteConfig.default`입니다.
    /// - Returns: 파싱된 결과를 담은 `ParsedDocument`
    /// - Throws: `DendriteError` (파일 읽기 실패, 지원하지 않는 파일 타입 또는 파싱 실패 시)
    public static func parse(
        from url: URL,
        config: DendriteConfig = .default
    ) async throws -> ParsedDocument {
        
        // 1. 파일 확장자를 기반으로 UTType을 결정합니다.
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            throw DendriteError.unsupportedFileType(fileExtension: url.pathExtension)
        }
        
        // 2. URL로부터 데이터를 비동기적으로 읽습니다.
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DendriteError.fileReadFailed(url: url, underlyingError: error)
        }
        
        // 3. 데이터와 타입을 사용하여 파싱을 수행합니다.
        return try await parse(data: data, fileType: type, config: config)
    }
    
    /// 데이터를 지정된 파일 타입으로 파싱합니다.
    ///
    /// 이 정적 메서드는 라이브러리의 핵심 공개 API(Facade) 역할을 합니다.
    /// 내부적으로 `ParserFactory`를 통해 `DendriteConfig`에 따라 적절한 파서를 선택하여 파싱 작업을 수행합니다.
    ///
    /// - Parameters:
    ///   - data: 파싱할 원본 데이터
    ///   - fileType: 데이터의 파일 타입 (`UTType`)
    ///   - config: 파서 구성 및 옵션을 포함하는 설정 객체. 기본값은 `DendriteConfig.default`입니다.
    /// - Returns: 파싱된 결과를 담은 `ParsedDocument`
    /// - Throws: `DendriteError` (지원하지 않는 파일 타입 또는 파싱 실패 시)
    public static func parse(
        data: Data,
        fileType: UTType,
        config: DendriteConfig = .default
    ) async throws -> ParsedDocument {
        
        // 1. 팩토리에 설정 객체의 파서 목록을 전달하여 적절한 파서를 가져옵니다.
        guard let parser = ParserFactory.parser(for: fileType, availableParsers: config.parsers) else {
            throw DendriteError.unsupportedFileType(fileExtension: fileType.preferredFilenameExtension ?? "unknown")
        }
        
        // 2. 해당 파서로 파싱을 실행하고 결과를 반환합니다.
        do {
            return try await parser.parse(data: data, type: fileType)
        } catch let dendriteError as DendriteError {
            // 이미 DendriteError인 경우, 다시 래핑하지 않고 그대로 전파합니다.
            // 개별 파서가 자신의 컨텍스트를 포함한 오류를 생성할 책임이 있습니다.
            throw dendriteError
        } catch {
            // DendriteError가 아닌 다른 종류의 오류가 발생한 경우,
            // 컨텍스트를 추가하여 래핑합니다.
            throw DendriteError.parsingFailed(parserName: String(describing: Swift.type(of: parser)), underlyingError: error)
        }
    }
}
