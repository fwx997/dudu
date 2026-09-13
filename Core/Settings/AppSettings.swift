//
//  AppSettings.swift
//  Legado-iOS
//
//  应用全局设置
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private init() {}

    // MARK: - 搜索设置

    @AppStorage("searchFilterType")
    var searchFilterType: SearchFilterType = .noFilter

    @AppStorage("searchSourceType")
    var searchSourceType: SourceType = .text

    // MARK: - 阅读设置

    @AppStorage("textConversionMode")
    var textConversionMode: TextConversionMode = .noConversion

    @AppStorage("readAloudMode")
    var readAloudMode: ReadAloudMode = .byPage

    // MARK: - 界面设置

    @AppStorage("showStatusBar")
    var showStatusBar: Bool = true

    @AppStorage("showBattery")
    var showBattery: Bool = true

    @AppStorage("showTime")
    var showTime: Bool = true

    @AppStorage("showProgress")
    var showProgress: Bool = true
}

// MARK: - 搜索过滤类型
enum SearchFilterType: String, CaseIterable {
    case noFilter = "no_filter"
    case matchKeyword = "match_keyword"
    case containsKeyword = "contains_keyword"

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
    case all = "all"
    case text = "text"
    case image = "image"
    case audio = "audio"
    case video = "video"

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
    case noConversion = "no_conversion"
    case toSimplified = "to_simplified"
    case toTraditional = "to_traditional"

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
    case byPage = "by_page"
    case byChapter = "by_chapter"

    var displayName: String {
        switch self {
        case .byPage: return "按页朗读"
        case .byChapter: return "按章朗读"
        }
    }
}

// MARK: - AppStorage 支持自定义枚举
extension SearchFilterType: RawRepresentable {}
extension SourceType: RawRepresentable {}
extension TextConversionMode: RawRepresentable {}
extension ReadAloudMode: RawRepresentable {}
