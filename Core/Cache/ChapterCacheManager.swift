//
//  ChapterCacheManager.swift
//  Legado-iOS
//
//  章节缓存预加载管理器
//  自动预加载当前章节前后 N 章的内容，减少等待时间
//  参考 Android CacheBook 的预缓存策略
//

import Foundation
import CoreData

@MainActor
final class ChapterCacheManager: ObservableObject {
    
    /// 预加载前后章节数（默认前后各 3 章）
    private let preloadCount: Int = 3
    
    /// 最大并发下载数
    private let maxConcurrency: Int = 3
    
    /// 缓存任务
    private var preloadTasks: [Task<Void, Never>] = []
    
    /// 缓存进度
    @Published var cachedChapterCount: Int = 0
    @Published var totalCacheTarget: Int = 0
    @Published var isCaching: Bool = false
    
    // MARK: - 预加载
    
    /// 基于当前章节位置，预加载前后章节
    func preloadAroundChapter(
        index: Int,
        chapters: [BookChapter],
        book: Book
    ) {
        // 取消旧任务
        cancelPreload()
        
        guard !chapters.isEmpty else { return }
        
        // 计算需要预加载的范围
        let startIndex = max(0, index - preloadCount)
        let endIndex = min(chapters.count - 1, index + preloadCount)
        
        var targetChapters: [BookChapter] = []
        for i in startIndex...endIndex {
            if i != index && !chapters[i].isCached {
                targetChapters.append(chapters[i])
            }
        }
        
        guard !targetChapters.isEmpty else { return }
        
        isCaching = true
        totalCacheTarget = targetChapters.count
        cachedChapterCount = 0
        
        // 分批预加载
        let task = Task { [weak self] in
            for chapter in targetChapters {
                guard !Task.isCancelled else { break }
                
                do {
                    try await self?.cacheChapterContent(chapter, book: book)
                    await MainActor.run {
                        self?.cachedChapterCount += 1
                    }
                } catch {
                    print("预缓存失败[\(chapter.title)]: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self?.isCaching = false
            }
        }
        
        preloadTasks.append(task)
    }
    
    // MARK: - 批量缓存（下载全书）
    
    /// 缓存指定范围的章节
    func cacheChapters(
        from startIndex: Int,
        to endIndex: Int,
        chapters: [BookChapter],
        book: Book,
        onProgress: ((Int, Int) -> Void)? = nil
    ) async {
        guard startIndex >= 0, endIndex < chapters.count, startIndex <= endIndex else { return }
        
        isCaching = true
        let total = endIndex - startIndex + 1
        totalCacheTarget = total
        cachedChapterCount = 0
        
        for i in startIndex...endIndex {
            guard !Task.isCancelled else { break }
            
            let chapter = chapters[i]
            
            // 跳过已缓存的
            if chapter.isCached { 
                cachedChapterCount += 1
                onProgress?(cachedChapterCount, total)
                continue 
            }
            
            do {
                try await cacheChapterContent(chapter, book: book)
                cachedChapterCount += 1
                onProgress?(cachedChapterCount, total)
            } catch {
                print("缓存失败[\(chapter.title)]: \(error.localizedDescription)")
                cachedChapterCount += 1 // 失败也计入进度
            }
        }
        
        isCaching = false
    }
    
    /// 缓存全书
    func cacheAllChapters(
        chapters: [BookChapter],
        book: Book,
        onProgress: ((Int, Int) -> Void)? = nil
    ) async {
        await cacheChapters(
            from: 0,
            to: chapters.count - 1,
            chapters: chapters,
            book: book,
            onProgress: onProgress
        )
    }
    
    // MARK: - 清理缓存
    
    /// 清理指定书籍的所有章节缓存
    func clearCache(for book: Book) throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chapterDir = documents.appendingPathComponent("chapters", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: chapterDir.path) else { return }
        
        let context = CoreDataStack.shared.viewContext
        
        // 清理文件
        if let chapters = book.chapters as? Set<BookChapter> {
            for chapter in chapters {
                if let cachePath = chapter.cachePath, !cachePath.isEmpty {
                    let fileURL = chapterDir.appendingPathComponent(cachePath)
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    chapter.isCached = false
                    chapter.cachePath = nil
                }
            }
        }
        
        try context.save()
    }
    
    /// 获取缓存大小
    func cacheSize(for book: Book) -> Int64 {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chapterDir = documents.appendingPathComponent("chapters", isDirectory: true)
        
        var totalSize: Int64 = 0
        
        if let chapters = book.chapters as? Set<BookChapter> {
            for chapter in chapters {
                guard let cachePath = chapter.cachePath, !cachePath.isEmpty else { continue }
                let fileURL = chapterDir.appendingPathComponent(cachePath)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return totalSize
    }
    
    /// 格式化缓存大小
    func formattedCacheSize(for book: Book) -> String {
        let bytes = cacheSize(for: book)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - 取消
    
    func cancelPreload() {
        for task in preloadTasks {
            task.cancel()
        }
        preloadTasks.removeAll()
        isCaching = false
    }
    
    // MARK: - 私有方法
    
    private func cacheChapterContent(_ chapter: BookChapter, book: Book) async throws {
        // 从网络获取内容
        guard !book.isLocal else { return }
        
        guard let sourceId = UUID(uuidString: book.origin) else {
            throw ReaderError.noSource
        }
        
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "sourceId == %@", sourceId as CVarArg)
        request.fetchLimit = 1
        
        guard let source = try context.fetch(request).first else {
            throw ReaderError.noSource
        }
        
        let content = try await WebBook.getContent(source: source, book: book, chapter: chapter)
        
        // 保存到文件
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chapterDir = documents.appendingPathComponent("chapters", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: chapterDir.path) {
            try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        }
        
        let fileName = "\(chapter.bookId.uuidString)_\(chapter.index).txt"
        let fileURL = chapterDir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        chapter.isCached = true
        chapter.cachePath = fileName
        try context.save()
    }
}
