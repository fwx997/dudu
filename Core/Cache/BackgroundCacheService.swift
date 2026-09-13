import Foundation
import CoreData
import BackgroundTasks

class BackgroundCacheService {
    static let shared = BackgroundCacheService()
    
    private let taskIdentifier = "com.chrn11.legado.cachebook"
    private var currentBook: Book?
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: (() -> Void)?
    
    private init() {
        registerBackgroundTask()
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    func scheduleCacheTask(for book: Book) {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            currentBook = book
        } catch {
            print("调度后台缓存失败: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        guard let book = currentBook else {
            task.setTaskCompleted(success: false)
            return
        }
        
        Task {
            do {
                try await cacheBook(book) { progress in
                    self.progressHandler?(progress)
                }
                task.setTaskCompleted(success: true)
                self.completionHandler?()
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func cacheBook(_ book: Book, progress: @escaping (Double) -> Void) async throws {
        guard let chapters = book.chapters as? Set<BookChapter> else { return }
        
        let sortedChapters = chapters.sorted { $0.index < $1.index }
        let total = sortedChapters.count
        var cached = 0
        
        let durIndex = Int(book.durChapterIndex)
        let startIndex = max(0, durIndex)
        
        for i in startIndex..<total {
            let chapter = sortedChapters[i]
            
            if chapter.contentHash == nil || chapter.contentHash?.isEmpty == true {
                do {
                    try await fetchAndCacheChapter(chapter, book: book)
                } catch {
                    continue
                }
            }
            
            cached += 1
            let progressValue = Double(cached) / Double(total - startIndex)
            await MainActor.run {
                progress(progressValue)
            }
        }
    }
    
    private func fetchAndCacheChapter(_ chapter: BookChapter, book: Book) async throws {
        guard let source = book.source else { return }
        
        let content = try await WebBook.getContent(
            source: source,
            book: book,
            chapter: chapter
        )
        
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("ChapterCache")
        
        let cachePath = cacheDir.appendingPathComponent("\(chapter.chapterId.uuidString).txt").path
        try content.write(to: URL(fileURLWithPath: cachePath), atomically: true, encoding: .utf8)
        
        chapter.contentHash = cachePath
        try CoreDataStack.shared.viewContext.save()
    }
    
    func cacheBookForeground(_ book: Book, progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        self.progressHandler = progress
        self.completionHandler = completion
        self.currentBook = book
        
        Task {
            do {
                try await cacheBook(book, progress: progress)
                await MainActor.run {
                    completion()
                }
            } catch {
                await MainActor.run {
                    completion()
                }
            }
        }
    }
}