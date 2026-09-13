//
//  SearchViewModel.swift
//  Legado-iOS
//
//  搜索 ViewModel
//

import Foundation
import CoreData

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var filteredResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var selectedSources: [BookSource] = []
    @Published var searchHistory: [String] = []
    @Published var hotWords: [String] = []
    @Published var searchedSourceCount = 0
    @Published var totalSourceCount = 0

    private var ruleEngine: RuleEngine = RuleEngine()
    private let settings = AppSettings.shared
    private let historyManager = SearchHistoryManager.shared
    private let hotWordsManager = SearchHotWordsManager.shared

    init() {
        loadDefaultSources()
        loadSearchHistory()
        loadHotWords()
    }

    private func loadDefaultSources() {
        do {
            let sources = try CoreDataStack.shared.viewContext.fetch(BookSource.fetchRequest())
            // 根据设置过滤书源类型
            let typeFiltered = SearchFilter.shared.filterBySourceType(sources, sourceType: settings.searchSourceType)
            selectedSources = typeFiltered.filter { $0.enabled && $0.searchUrl != nil }
        } catch {
            selectedSources = []
        }
    }

    private func loadSearchHistory() {
        searchHistory = historyManager.history
    }

    private func loadHotWords() {
        hotWords = hotWordsManager.hotWords
    }

    /// 刷新书源（当用户更改书源类型设置时调用）
    func refreshSources() {
        loadDefaultSources()
    }
    
    // MARK: - 搜索结果
    struct SearchResult: Identifiable {
        let id = UUID()
        let name: String
        let author: String
        let coverUrl: String?
        let intro: String?
        let sourceName: String
        let sourceId: UUID
        let bookUrl: String

        var displayName: String {
            // 应用繁简转换
            TextConverter.shared.convert(name.trimmingCharacters(in: .whitespaces))
        }

        var displayAuthor: String {
            TextConverter.shared.convert(author.trimmingCharacters(in: .whitespaces))
        }

        var displayIntro: String? {
            guard let intro = intro else { return nil }
            return TextConverter.shared.convert(intro)
        }
    }
    
    // MARK: - 执行搜索

    /// 同时在搜的源数量上限：防止把弱站点和手机网络打爆
    private static let maxConcurrentSources = 12
    /// 单个书源搜索超时（秒）：超时的源放弃，不拖慢整体
    private static let sourceTimeoutSeconds: UInt64 = 10

    func search(keyword: String, sources: [BookSource]) async {
        guard !keyword.isEmpty else {
            searchResults = []
            filteredResults = []
            isSearching = false
            return
        }

        historyManager.add(keyword)
        loadSearchHistory()

        isSearching = true
        searchResults.removeAll()
        filteredResults.removeAll()
        errorMessage = nil
        searchedSourceCount = 0

        let typeFiltered = SearchFilter.shared.filterBySourceType(sources, sourceType: settings.searchSourceType)
        let enabledSources = typeFiltered.filter { $0.enabled && $0.searchUrl != nil }
        totalSourceCount = enabledSources.count

        var nextIndex = 0
        var seenBookKeys = Set<String>()

        await withTaskGroup(of: [SearchResult].self) { group in
            func addNextSource() {
                guard nextIndex < enabledSources.count else { return }
                let source = enabledSources[nextIndex]
                nextIndex += 1
                group.addTask {
                    await self.searchWithTimeout(keyword: keyword, source: source)
                }
            }

            for _ in 0..<min(Self.maxConcurrentSources, enabledSources.count) {
                addNextSource()
            }

            // 流式回填：哪个源先出结果就先显示哪个，不等全部搜完
            while let partial = await group.next() {
                searchedSourceCount += 1
                for result in partial {
                    let key = result.displayName + "|" + result.displayAuthor
                    if seenBookKeys.insert(key.lowercased()).inserted {
                        searchResults.append(result)
                    }
                }
                applyFilter(keyword: keyword)
                if !Task.isCancelled {
                    addNextSource()
                }
            }
        }

        if Task.isCancelled {
            errorMessage = "搜索已取消"
        }
        isSearching = false
    }

    /// 单源搜索，套一层超时：结果和超时赛跑，先到者胜，输家被取消
    private nonisolated func searchWithTimeout(keyword: String, source: BookSource) async -> [SearchResult] {
        await withTaskGroup(of: [SearchResult]?.self) { inner in
            inner.addTask {
                (try? await self.searchInSource(keyword: keyword, source: source)) ?? []
            }
            inner.addTask {
                try? await Task.sleep(nanoseconds: Self.sourceTimeoutSeconds * 1_000_000_000)
                return nil
            }
            var results: [SearchResult] = []
            if let first = await inner.next() {
                results = first ?? []
            }
            inner.cancelAll()
            return results
        }
    }

    /// 应用搜索过滤
    private func applyFilter(keyword: String) {
        let filtered = SearchFilter.shared.filter(
            searchResults,
            keyword: keyword,
            filterType: settings.searchFilterType,
            getName: { $0.displayName }
        )

        // 智能排序
        filteredResults = SearchFilter.shared.sortResults(
            filtered,
            keyword: keyword,
            getName: { $0.displayName }
        )
    }

    /// 重新应用过滤（当用户更改过滤设置时调用）
    func reapplyFilter() {
        guard !searchText.isEmpty else { return }
        applyFilter(keyword: searchText)
    }
    
    // MARK: - 在单个书源中搜索

    private nonisolated func searchInSource(keyword: String, source: BookSource) async throws -> [SearchResult] {
        // 使用 WebBook 进行搜索
        let results = try await WebBook.searchBook(source: source, key: keyword)
        
        return results.map { searchBook in
            SearchResult(
                name: searchBook.name,
                author: searchBook.author,
                coverUrl: searchBook.coverUrl,
                intro: searchBook.intro,
                sourceName: source.bookSourceName,
                sourceId: source.sourceId,
                bookUrl: searchBook.bookUrl
            )
        }
    }
    
    // MARK: - 添加到书架
    func addToBookshelf(result: SearchResult) async throws -> Book {
        let context = CoreDataStack.shared.viewContext

        if let existing = findBook(bookUrl: result.bookUrl, origin: result.sourceId.uuidString, in: context) {
            existing.name = result.name
            existing.author = result.author
            existing.coverUrl = result.coverUrl
            existing.intro = result.intro
            existing.originName = result.sourceName
            existing.updatedAt = Date()
            try CoreDataStack.shared.save()
            return existing
        }

        let book = Book.create(in: context)
        book.name = result.name
        book.author = result.author
        book.coverUrl = result.coverUrl
        book.intro = result.intro
        book.bookUrl = result.bookUrl
        book.tocUrl = ""
        book.origin = result.sourceId.uuidString
        book.originName = result.sourceName

        let sourceRequest: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        sourceRequest.fetchLimit = 1
        sourceRequest.predicate = NSPredicate(format: "sourceId == %@", result.sourceId as CVarArg)
        if let source = try? context.fetch(sourceRequest).first {
            book.source = source
        }

        try CoreDataStack.shared.save()
        return book
    }

    private func findBook(bookUrl: String, origin: String, in context: NSManagedObjectContext) -> Book? {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookUrl == %@ AND origin == %@", bookUrl, origin)
        return try? context.fetch(request).first
    }

    // MARK: - 搜索历史管理

    /// 删除搜索历史项
    func removeHistory(_ keyword: String) {
        historyManager.remove(keyword)
        loadSearchHistory()
    }

    /// 清空搜索历史
    func clearHistory() {
        historyManager.clearAll()
        loadSearchHistory()
    }

    /// 使用历史关键词搜索
    func searchWithHistory(_ keyword: String) {
        searchText = keyword
        Task {
            await search(keyword: keyword, sources: selectedSources)
        }
    }

    /// 使用热词搜索
    func searchWithHotWord(_ word: String) {
        searchText = word
        Task {
            await search(keyword: word, sources: selectedSources)
        }
    }
}

// MARK: - 错误类型
enum SearchError: LocalizedError {
    case invalidSource
    case noSearchRule
    case networkFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidSource: return "书源无效"
        case .noSearchRule: return "缺少搜索规则"
        case .networkFailure: return "网络请求失败"
        }
    }
}
