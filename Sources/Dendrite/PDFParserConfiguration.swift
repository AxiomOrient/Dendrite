// Sources/Dendrite/PDFParserConfiguration.swift

import Foundation

/// `PDFParser`의 동작을 구성하는 설정 객체입니다.
///
/// `Sendable`을 준수하여 동시성 환경에서 안전하게 전달될 수 있습니다.
public struct PDFParserConfiguration: Sendable {
    
    /// OCR을 트리거할 텍스트 길이의 임계값입니다.
    public static let defaultTextThreshold = 50

    /// 네이티브 텍스트 추출 후, 텍스트의 길이가 이 값보다 작을 경우 OCR을 수행합니다.
    ///
    /// 이미지 기반 PDF 페이지나 텍스트가 거의 없는 페이지에 대해 OCR을 강제하는 역할을 합니다.
    public let textThreshold: Int
    
    /// PDF 페이지에 OCR을 수행할 때 사용할 설정입니다.
    ///
    /// 자세한 내용은 ``OCRConfiguration``을 참고하세요.
    public let ocrConfiguration: OCRConfiguration

    /// PDF 파서 설정을 초기화합니다.
    /// - Parameters:
    ///   - textThreshold: OCR을 트리거할 텍스트 길이의 임계값. 기본값은 `50`입니다.
    ///   - ocrConfiguration: OCR 수행 시 사용할 설정. 기본값은 `.init()`입니다.
    public init(
        textThreshold: Int = Self.defaultTextThreshold,
        ocrConfiguration: OCRConfiguration = .init()
    ) {
        self.textThreshold = textThreshold
        self.ocrConfiguration = ocrConfiguration
    }
}
