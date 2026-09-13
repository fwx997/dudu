//
//  Chapter.swift
//  Legado
//
//  章节数据模型
//

import Foundation
import SwiftData

/// 章节模型
@Model
final class Chapter: Identifiable, Codable {
    // MARK: - 基本信息
    @Attribute(.unique) var id: String          // 章节唯一 ID
    var title: String                           // 章节标题
    var index: Int                              // 章节索引
    var content: String                         // 章节内容
    var wordCount: Int = 0                      // 字数
    var sourceUrl: String?                      // 来源 URL
    
    // MARK: - 时间戳
    var createdDate: Date = Date()
    var updatedDate: Date = Date()
    
    // MARK: - 关系
    @Relationship var book: Book?
    
    // MARK: - 初始化
    init(
        id: String = UUID().uuidString,
        title: String,
        index: Int,
        content: String = "",
        wordCount: Int = 0,
        sourceUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.index = index
        self.content = content
        self.wordCount = wordCount
        self.sourceUrl = sourceUrl
    }
    
    // MARK: - 计算属性
    var displayTitle: String {
        title.isEmpty ? "第\(index + 1)章" : title
    }
    
    var contentPreview: String {
        if content.isEmpty {
            return "暂无内容"
        }
        let previewLength = min(100, content.count)
        return String(content.prefix(previewLength)) + "..."
    }
}
