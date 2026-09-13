//
//  Book.swift
//  Legado
//
//  书籍数据模型
//

import Foundation
import SwiftData

/// 书籍模型
@Model
final class Book: Identifiable, Codable {
    // MARK: - 基本信息
    @Attribute(.unique) var id: String          // 书籍唯一 ID
    var title: String                           // 书名
    var author: String                          // 作者
    var coverUrl: String?                       // 封面图片 URL
    var introduction: String?                   // 简介
    
    // MARK: - 来源信息
    var sourceId: String?                       // 书源 ID
    var sourceUrl: String?                      // 源网址
    var bookUrl: String?                        // 书籍详情 URL
    
    // MARK: - 文件信息
    var localFileUrl: String?                   // 本地文件路径
    var filePath: String?                       // 本地文件存储路径
    var chapterCount: Int = 0                   // 章节数
    
    // MARK: - 阅读进度
    var lastReadDate: Date?                     // 最后阅读时间
    var readProgress: Double = 0                // 阅读进度 (0-1)
    var lastChapterIndex: Int = 0               // 最后阅读章节索引
    var lastReadPosition: Int = 0               // 最后阅读位置
    
    // MARK: - 时间戳
    var createdDate: Date = Date()              // 添加时间
    var updatedDate: Date = Date()              // 更新时间
    
    // MARK: - 关系
    @Relationship(deleteRule: .cascade) var chapters: [Chapter] = []
    @Relationship(deleteRule: .cascade) var bookmarks: [Bookmark] = []
    @Relationship(deleteRule: .cascade) var highlights: [Highlight] = []
    @Relationship var readRecord: ReadRecord?
    
    // MARK: - 初始化
    init(
        id: String = UUID().uuidString,
        title: String,
        author: String = "未知作者",
        coverUrl: String? = nil,
        introduction: String? = nil,
        sourceId: String? = nil,
        sourceUrl: String? = nil,
        bookUrl: String? = nil,
        localFileUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverUrl = coverUrl
        self.introduction = introduction
        self.sourceId = sourceId
        self.sourceUrl = sourceUrl
        self.bookUrl = bookUrl
        self.localFileUrl = localFileUrl
    }
    
    // MARK: - 计算属性
    var displayTitle: String {
        title.isEmpty ? "无题" : title
    }
    
    var displayAuthor: String {
        author.isEmpty ? "未知" : author
    }
    
    var hasCover: Bool {
        coverUrl != nil && !coverUrl!.isEmpty
    }
    
    var isLocalBook: Bool {
        localFileUrl != nil && !localFileUrl!.isEmpty
    }
    
    var readProgressText: String {
        "\(Int(readProgress * 100))%"
    }
    
    var lastReadDateText: String {
        guard let date = lastReadDate else { return "未阅读" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 书籍列表扩展
extension Book {
    /// 按阅读时间排序
    static func sortByReadDate() -> SortDescriptor<Book> {
        SortDescriptor(\Book.lastReadDate, order: .reverse)
    }
    
    /// 按添加时间排序
    static func sortByAddDate() -> SortDescriptor<Book> {
        SortDescriptor(\Book.createdDate, order: .reverse)
    }
    
    /// 按书名字母排序
    static func sortByName() -> SortDescriptor<Book> {
        SortDescriptor(\Book.title, order: .forward)
    }
}
