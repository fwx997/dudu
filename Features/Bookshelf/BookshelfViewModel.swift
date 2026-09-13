//
//  BookshelfViewModel.swift
//  Legado-iOS
//
//  书架 ViewModel
//

import Foundation
import CoreData
import Combine

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    
    @Published var viewMode: ViewMode = .grid
    @Published var groupFilter: Int32 = 0
    @Published var sortBy: SortBy = .lastRead
    
    private let pageSize = 50
    private var currentPage = 0
    
    enum ViewMode: Int, CaseIterable {
        case grid = 0
        case list = 1
    }
    
    enum SortBy: Int, CaseIterable {
        case lastRead = 0
        case name = 1
        case author = 2
        case update = 3
        case manual = 4
    }
    
    private var loadTask: Task<Void, Never>?
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadBooks() async {
        guard !isLoading else { return }

        isLoading = true
        currentPage = 0

        do {
            let firstPage = try await fetchBooks(page: 0, size: pageSize)
            print("📚 loadBooks: 获取到 \(firstPage.count) 本书")
            for book in firstPage.prefix(3) {
                print("  - \(book.name) (origin: \(book.origin))")
            }
            books = firstPage
            hasMore = firstPage.count == pageSize
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            print("❌ loadBooks 失败: \(error)")
        }

        isLoading = false
    }
    
    func forceReload() async {
        print("🔄 forceReload: 强制刷新书架")
        isLoading = false
        await loadBooks()
    }
    
    func loadMoreBooks() async {
        guard !isLoading && hasMore else { return }

        isLoading = true

        do {
            currentPage += 1
            let nextPage = try await fetchBooks(page: currentPage, size: pageSize)
            books.append(contentsOf: nextPage)
            hasMore = nextPage.count == pageSize
        } catch {
            errorMessage = "加载更多失败：\(error.localizedDescription)"
        }

        isLoading = false
    }
    
    private func fetchBooks(page: Int, size: Int) async throws -> [Book] {
        let context = CoreDataStack.shared.viewContext

        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.fetchLimit = size
        request.fetchOffset = page * size

        if groupFilter != 0 {
            request.predicate = NSPredicate(format: "group == %d", groupFilter)
        }

        switch sortBy {
        case .lastRead:
            request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        case .name:
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        case .author:
            request.sortDescriptors = [NSSortDescriptor(key: "author", ascending: true)]
        case .update:
            request.sortDescriptors = [NSSortDescriptor(key: "lastCheckTime", ascending: false)]
        case .manual:
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        }

        return try context.fetch(request)
    }
    
    func refreshBooks() async {
        await loadBooks()
    }

    // MARK: - 更新检查

    @Published var isCheckingUpdates = false
    @Published var updateSummary: String?

    /// 检查书架更新：香色闺阁站点书籍走 bookDetail 取最新章节，有新章则刷新书架显示
    func checkUpdates() async {
        let context = CoreDataStack.shared.viewContext
        let all = (try? context.fetch(Book.fetchRequest())) ?? []
        let xbsBooks = all.filter { $0.origin.hasPrefix("xbs://") }
        guard !xbsBooks.isEmpty else {
            updateSummary = nil
            return
        }

        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        var updatedCount = 0
        await withTaskGroup(of: (Book, String?).self) { group in
            var iterator = xbsBooks.makeIterator()
            var running = 0
            let maxConcurrent = 6

            func addNext() {
                guard running < maxConcurrent, let book = iterator.next() else { return }
                running += 1
                group.addTask {
                    let alias = String(book.origin.dropFirst("xbs://".count))
                    guard let source = XBSSourceStore.shared.source(alias: alias),
                          let detail = try? await XBSEngine.shared.bookDetail(source: source, url: book.bookUrl) else {
                        return (book, nil)
                    }
                    return (book, detail.lastChapterTitle)
                }
            }

            for _ in 0..<maxConcurrent { addNext() }

            for await (book, latest) in group {
                running -= 1
                addNext()
                if let latest, !latest.isEmpty, latest != book.latestChapterTitle {
                    book.latestChapterTitle = latest
                    updatedCount += 1
                }
            }
        }

        if updatedCount > 0 {
            try? CoreDataStack.shared.save()
            await loadBooks()
        }
        updateSummary = updatedCount > 0 ? "发现 \(updatedCount) 本有更新" : "暂无更新"
    }

    func removeBook(_ book: Book) {
        CoreDataStack.shared.viewContext.delete(book)
        try? CoreDataStack.shared.save()
    }

    /// 编辑模式：列表拖拽排序（对齐 onMoveEvent:），持久化 order
    func moveBookAt(from: IndexSet, to: Int) {
        var arr = books
        arr.move(fromOffsets: from, toOffset: to)
        for (i, b) in arr.enumerated() { b.order = Int32(i) }
        try? CoreDataStack.shared.save()
        Task { await forceReload() }
    }

    /// 编辑模式：批量移动到书架（对齐 onMoveEvent:）
    func moveBooks(_ books: [Book], to group: Int64) {
        for b in books { b.group = group }
        try? CoreDataStack.shared.save()
        Task { await forceReload() }
    }

    /// 编辑模式：批量删除（对齐 onDeleteEvent:）
    func deleteBooks(_ books: [Book]) {
        let context = CoreDataStack.shared.viewContext
        for b in books { context.delete(b) }
        try? CoreDataStack.shared.save()
        Task { await forceReload() }
    }
    
    func updateGroup(for book: Book, group: Int32) {
        book.group = Int64(group)
        try? CoreDataStack.shared.save()
    }
}