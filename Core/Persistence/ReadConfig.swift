//
//  ReadConfig.swift
//  Legado-iOS
//
//  阅读配置结构体
//

import Foundation
import CoreData

/// 阅读配置（对应 Android ReadConfig）
struct ReadConfig: Codable {
    // MARK: - 基础设置
    var reverseToc: Bool           // 反向目录
    var pageAnim: Int32            // 翻页动画 (0=覆盖，1=仿真，2=滑动，3=滚动)
    var reSegment: Bool            // 重分段
    var imageStyle: String?        // 图片样式 (FULL, ORIGINAL, NONE)
    var useReplaceRule: Bool       // 使用替换规则
    
    // MARK: - TTS 设置
    var ttsEngine: String?         // TTS 引擎
    
    // MARK: - 进度设置
    var delTag: Int64              // 删除标记
    var startDate: Date?           // 开始阅读日期
    var startChapter: Int32        // 开始章节索引
    var dailyChapters: Int32       // 每日章节数
    
    // MARK: - 其他
    var splitLongChapter: Bool     // 分割长章节
    var readSimulating: Bool       // 模拟阅读
    
    // MARK: - 默认值
    init() {
        self.reverseToc = false
        self.pageAnim = 0
        self.reSegment = false
        self.imageStyle = nil
        self.useReplaceRule = true
        self.ttsEngine = nil
        self.delTag = 0
        self.startDate = nil
        self.startChapter = 0
        self.dailyChapters = 3
        self.splitLongChapter = true
        self.readSimulating = false
    }
    
    // MARK: - 编码键
    enum CodingKeys: String, CodingKey {
        case reverseToc, pageAnim, reSegment, imageStyle
        case useReplaceRule, ttsEngine, delTag
        case startDate, startChapter, dailyChapters
        case splitLongChapter, readSimulating
    }
}

// MARK: - 翻页动画枚举
enum PageAnimation: Int32, CaseIterable {
    case cover = 0      // 覆盖
    case simulation = 1 // 仿真
    case slide = 2      // 滑动
    case scroll = 3     // 滚动
    
    var displayName: String {
        switch self {
        case .cover: return "覆盖"
        case .simulation: return "仿真"
        case .slide: return "滑动"
        case .scroll: return "滚动"
        }
    }
}

// MARK: - 图片样式枚举
enum ImageStyle: String, CaseIterable {
    case full = "FULL"
    case original = "ORIGINAL"
    case none = "NONE"
    
    var displayName: String {
        switch self {
        case .full: return "充满屏幕"
        case .original: return "原始比例"
        case .none: return "不显示"
        }
    }
}
