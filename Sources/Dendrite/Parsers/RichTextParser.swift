// Sources/Dendrite/Parsers/RichTextParser.swift

import Foundation
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

    // MARK: - Properties

    public var supportedTypes: [UTType] {
        var types: [UTType?] = [.rtf, .html]
        
        // --- FIX: .docx 지원 여부를 컴파일 타임에 결정 ---
        // AppKit을 사용할 수 있는 환경(macOS)에서만 .docx 타입을 지원 목록에 추가합니다.
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        types.append(UTType("org.openxmlformats.wordprocessingml.document"))
        #endif
        
        return types.compactMap { $0 }
    }

    // MARK: - ParserProtocol Implementation

    public func parse(data: Data, type: UTType) async throws -> ParsedDocument {
        // --- FIX: documentType(for:) 헬퍼 함수를 사용하여 플랫폼에 맞는 타입을 반환 ---
        guard let docType = documentType(for: type) else {
            // 이 로직은 supportedTypes에 의해 이미 필터링되지만, 안전을 위해 추가합니다.
            throw DendriteError.unsupportedFileType(fileExtension: type.preferredFilenameExtension ?? "unknown")
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: docType]

        do {
            try Task.checkCancellation()
            
            var documentAttributes: NSDictionary?
            let attributedString = try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: &documentAttributes
            )
            
            let markdownContent = attributedString.toMarkdown()
            var metadata = DocumentMetadata()

            // --- FIX: macOS에서만 사용 가능한 title 키를 조건부로 사용 ---
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // AppKit에서는 NSAttributedString.Key.title을 사용할 수 있습니다.
            // 하지만, 더 범용적인 문자열 키 "title"을 사용하는 것이 안전할 수 있습니다.
            // 여기서는 documentAttributes 딕셔너리가 반환하는 키를 직접 확인합니다.
            if let title = documentAttributes?[ "title" /* NSAttributedString.Key.title.rawValue */ ] as? String {
                metadata.title = title
            }
            #endif
            
            return ParsedDocument(
                content: markdownContent,
                metadata: metadata
            )
        } catch {
            throw DendriteError.parsingFailed(parserName: "RichTextParser", underlyingError: error)
        }
    }
    
    // MARK: - Private Helper
    
    /// 주어진 UTType에 맞는 `NSAttributedString.DocumentType`을 반환합니다.
    /// DOCX는 macOS에서만 지원되므로, 해당 플랫폼이 아닐 경우 nil을 반환할 수 있습니다.
    private func documentType(for type: UTType) -> NSAttributedString.DocumentType? {
        if type.conforms(to: .rtf) {
            return .rtf
        } else if type.conforms(to: .html) {
            return .html
        }
        
        // --- FIX: .officeOpenXML을 macOS에서만 조건부로 반환 ---
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let docxType = UTType("org.openxmlformats.wordprocessingml.document"), type.conforms(to: docxType) {
            return .officeOpenXML
        }
        #endif
        
        return nil
    }
}
