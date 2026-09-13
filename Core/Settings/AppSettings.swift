//
//  AppSettings.swift
//  Legado-iOS
//
//  应用全局设置（手动 UserDefaults 持久化）
//

import Foundation
import Combine

// MARK: - 搜索过滤类型

enum SearchFilterType: String, CaseIterable {
    case noFilter
    case matchKeyword
    case containsKeyword

    var displayName: String {
        switch self {
        case .noFilter: return "不过滤"
        case .matchKeyword: return "匹配关键字"
        case .containsKeyword: return "包含关键字"
        }
    }
}

// MARK: - 书源类型

enum SourceType: String, CaseIterable {
    case all
    case text
    case image
    case audio
    case video

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .text: return "文本"
        case .image: return "图片"
        case .audio: return "音频"
        case .video: return "视频"
        }
    }
}

// MARK: - 文本转换模式

enum TextConversionMode: String, CaseIterable {
    case noConversion
    case toSimplified
    case toTraditional

    var displayName: String {
        switch self {
        case .noConversion: return "不转换"
        case .toSimplified: return "转简体"
        case .toTraditional: return "转繁体"
        }
    }
}

// MARK: - 朗读模式

enum ReadAloudMode: String, CaseIterable {
    case byPage
    case byChapter

    var displayName: String {
        switch self {
        case .byPage: return "按页朗读"
        case .byChapter: return "按章朗读"
        }
    }
}

// MARK: - 全局设置

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var searchFilterType: SearchFilterType {
        didSet { defaults.set(searchFilterType.rawValue, forKey: "dudu.searchFilterType") }
    }

    @Published var searchSourceType: SourceType {
        didSet { defaults.set(searchSourceType.rawValue, forKey: "dudu.searchSourceType") }
    }

    @Published var textConversionMode: TextConversionMode {
        didSet { defaults.set(textConversionMode.rawValue, forKey: "dudu.textConversionMode") }
    }

    @Published var readAloudMode: ReadAloudMode {
        didSet { defaults.set(readAloudMode.rawValue, forKey: "dudu.readAloudMode") }
    }

    private init() {
        searchFilterType = SearchFilterType(rawValue: defaults.string(forKey: "dudu.searchFilterType") ?? "") ?? .noFilter
        searchSourceType = SourceType(rawValue: defaults.string(forKey: "dudu.searchSourceType") ?? "") ?? .text
        textConversionMode = TextConversionMode(rawValue: defaults.string(forKey: "dudu.textConversionMode") ?? "") ?? .noConversion
        readAloudMode = ReadAloudMode(rawValue: defaults.string(forKey: "dudu.readAloudMode") ?? "") ?? .byPage
    }
}
