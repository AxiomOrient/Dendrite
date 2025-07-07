// Sources/Dendrite/Parsers/RichTextParser.swift

import Foundation
import SwiftSoup
import UniformTypeIdentifiers

// AppKit을 임포트하여 macOS 전용 API를 사용합니다.
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// DOCX, HTML, RTF 등 `NSAttributedString`으로 변환 가능한 리치 텍스트 파일을 처리하는 파서입니다.
///
/// Apple의 네이티브 프레임워크를 활용하여 여러 파일 형식을 단일 로직으로 처리하고,
/// 그 결과를 의미론적 구조가 보존된 마크다운으로 변환합니다.
/// DOCX 파싱은 AppKit이 사용 가능한 macOS에서만 지원됩니다.
struct RichTextParser: ParserProtocol {
    static let name = "RichTextParser"
    
    // MARK: - Properties
    
    public var supportedTypes: [UTType] {
        var types: [UTType?] = [.rtf, .html]
        
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
        types.append(UTType("org.openxmlformats.wordprocessingml.document"))
#endif
        
        return types.compactMap { $0 }
    }
    
    // MARK: - ParserProtocol Implementation
    
    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        guard let docType = documentType(for: type) else {
            throw DendriteError.unsupportedFileType(fileExtension: type.preferredFilenameExtension ?? "unknown")
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: docType]
        
        do {
            try Task.checkCancellation()
            
            // 1. NSAttributedString으로 리치 텍스트를 로드합니다.
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            
            // 2. 신뢰성 높은 HTML 변환을 위해 HTML 데이터로 먼저 변환합니다.
            let htmlData = try attributedString.data(
                from: .init(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            
            // 3. HTML 파싱을 HTMLParser에 위임합니다.
            let htmlParser = HTMLParser()
            return try await htmlParser.parse(data: htmlData, type: .html)
            
        } catch {
            throw DendriteError.parsingFailed(parserName: Self.name, underlyingError: error)
        }
    }
    
    // MARK: - Private Helper
    
    private func documentType(for type: UTType) -> NSAttributedString.DocumentType? {
        if type.conforms(to: .rtf) {
            return .rtf
        } else if type.conforms(to: .html) {
            return .html
        }
        
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let docxType = UTType("org.openxmlformats.wordprocessingml.document"), type.conforms(to: docxType) {
            return .officeOpenXML
        }
#endif
        
        return nil
    }
}
