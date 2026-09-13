//
//  TextConverter.swift
//  Legado-iOS
//
//  繁简体转换工具
//

import Foundation

class TextConverter {
    static let shared = TextConverter()

    private let settings = AppSettings.shared

    private init() {}

    /// 转换文本（根据设置）
    func convert(_ text: String) -> String {
        switch settings.textConversionMode {
        case .noConversion:
            return text
        case .toSimplified:
            return toSimplified(text)
        case .toTraditional:
            return toTraditional(text)
        }
    }

    /// 转换为简体
    func toSimplified(_ text: String) -> String {
        return text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
    }

    /// 转换为繁体
    func toTraditional(_ text: String) -> String {
        return text.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) ?? text
    }

    /// 批量转换
    func convertBatch(_ texts: [String]) -> [String] {
        texts.map { convert($0) }
    }
}

// MARK: - String 扩展
extension String {
    /// 转换为简体
    var toSimplified: String {
        TextConverter.shared.toSimplified(self)
    }

    /// 转换为繁体
    var toTraditional: String {
        TextConverter.shared.toTraditional(self)
    }

    /// 根据设置转换
    var converted: String {
        TextConverter.shared.convert(self)
    }
}
