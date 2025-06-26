// Sources/Dendrite/Extensions/NSAttributedString+Markdown.swift

import Foundation

#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformParagraphStyle = NSParagraphStyle
#elseif canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformParagraphStyle = NSParagraphStyle
#endif

extension NSAttributedString {
    
    /// NSAttributedString을 분석하여 Markdown 문자열로 변환합니다.
    /// [업그레이드] 목록(bullet point)과 인용(blockquote) 서식을 지원합니다.
    func toMarkdown() -> String { //
        var markdownString = ""
        let fullRange = NSRange(location: 0, length: self.length)
        
        self.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let text = self.attributedSubstring(from: range).string.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return }
            
            var processedText = text
            
            // --- 서식 처리 ---
            var isHeader = false
            
            // 폰트 속성 확인 (헤더, 볼드, 이탤릭)
            if let font = attributes[.font] as? PlatformFont { //
                let descriptor = font.fontDescriptor //
                let pointSize = font.pointSize //
                
                if pointSize > 30 { processedText = "# \(text)"; isHeader = true } //
                else if pointSize > 24 { processedText = "## \(text)"; isHeader = true } //
                else if pointSize > 18 { processedText = "### \(text)"; isHeader = true } //
                else {
                    var isBold = false //
                    var isItalic = false //
                    
                    #if canImport(AppKit)
                    isBold = descriptor.symbolicTraits.contains(.bold) //
                    isItalic = descriptor.symbolicTraits.contains(.italic) //
                    #elseif canImport(UIKit)
                    isBold = descriptor.symbolicTraits.contains(.traitBold) //
                    isItalic = descriptor.symbolicTraits.contains(.traitItalic) //
                    #endif

                    if isBold { processedText = "**\(processedText)**" } //
                    if isItalic { processedText = "*\(processedText)*" } //
                }
            }
            
            // [추가] 단락 스타일 확인 (목록, 인용)
            if let paragraphStyle = attributes[.paragraphStyle] as? PlatformParagraphStyle {
                let indent = paragraphStyle.headIndent
                // headIndent 값은 실험을 통해 적절한 값을 찾아 조정할 수 있습니다.
                if indent > 10 && !isHeader {
                    let prefix: String
                    // 텍스트 마커를 확인하여 목록과 인용을 구분합니다.
                    if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("∙") {
                        prefix = "* " // Bullet point
                        processedText.remove(at: processedText.startIndex) // 마커 제거
                        processedText = processedText.trimmingCharacters(in: .whitespaces)
                    } else {
                        prefix = "> " // Blockquote
                    }
                    processedText = prefix + processedText
                }
            }

            // 링크 속성 확인
            if let link = attributes[.link] { //
                if let url = link as? URL { //
                    processedText = "[\(text)](\(url.absoluteString))" //
                } else if let urlString = link as? String { //
                    processedText = "[\(text)](\(urlString))" //
                }
            }
            
            markdownString.append(processedText + "\n\n")
        }
        
        return markdownString.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression) //
    }
}
