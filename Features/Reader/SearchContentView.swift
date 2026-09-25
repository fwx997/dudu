//
//  SearchContentView.swift
//  Legado-iOS
//
//  书内全文搜索 - Phase 4
//

import SwiftUI
import CoreData

struct SearchContentView: View {
    @StateObject private var viewModel: SearchContentViewModel
    @Binding var isPresented: Bool
    let onResultTap: (Int, Int) -> Void
    
    init(book: Book, isPresented: Binding<Bool>, onResultTap: @escaping (Int, Int) -> Void) {
        _viewModel = StateObject(wrappedValue: SearchContentViewModel(book: book))
        _isPresented = isPresented
        self.onResultTap = onResultTap
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText, isSearching: $viewModel.isSearching) {
                    Task { await viewModel.search() }
                }
                
                if viewModel.isSearching {
                    ProgressView("搜索已缓存内容...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty {
                    if viewModel.searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundColor(.gray)
                            Text("搜索已缓存内容").foregroundColor(.gray)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "xmark.magnifyingglass").font(.system(size: 48)).foregroundColor(.gray)
                            Text("未找到结果").foregroundColor(.gray)
                        }
                    }
                } else {
                    List(viewModel.results) { result in
                        Button {
                            onResultTap(result.chapterIndex, result.position)
                            isPresented = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.chapterTitle).font(.headline)
                                Text(result.preview).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("书内搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            TextField("搜索章节内容", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit { onSearch() }
            
            if !text.isEmpty {
                Button("清除") { text = "" }
            }
            Button("搜索", action: onSearch)
        }
        .padding()
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let position: Int
    let preview: String
}

// 供后台扫描使用的纯值快照，避免跨线程访问 CoreData 管理对象
private struct ChapterScanItem: Sendable {
    let index: Int
    let title: String
    let cachePath: String?
}

private enum ChapterContentScan {
    static func fileContent(cachePath: String?) -> String? {
        guard let cachePath, !cachePath.isEmpty else { return nil }
        let url: URL
        if cachePath.hasPrefix("/") {
            url = URL(fileURLWithPath: cachePath)
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            url = documents.appendingPathComponent("chapters").appendingPathComponent(cachePath)
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // 与 ReaderViewModel.loadLocalChapterContent 相同的分章规则，一次性切片供逐章搜索
    static func splitLocalChapters(path: String) -> [String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let patterns = [
            #"^第[零一二三四五六七八九十百千万0-9]+[章回卷节部篇]"#,
            #"^第[0-9]+章"#,
            #"^Chapter [0-9]+"#,
            #"^\s*第[0-9一二三四五六七八九十]+节"#
        ]
        var slices: [String] = []
        var currentContent = ""
        var started = false
        for line in content.components(separatedBy: .newlines) {
            var isChapterStart = false
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            if isChapterStart {
                if started { slices.append(currentContent.trimmingCharacters(in: .whitespaces)) }
                started = true
                currentContent = ""
            } else if started {
                currentContent += line + "\n"
            }
        }
        if started { slices.append(currentContent.trimmingCharacters(in: .whitespaces)) }
        if slices.isEmpty { return [content] }
        return slices
    }

    static func scan(keyword: String, items: [ChapterScanItem], localSlices: [String]) -> [SearchResult] {
        var found: [SearchResult] = []
        for (i, item) in items.enumerated() {
            let content = fileContent(cachePath: item.cachePath) ?? (i < localSlices.count ? localSlices[i] : nil)
            guard let content, !content.isEmpty else { continue }
            var offset = 0
            while let range = content.range(of: keyword, options: .caseInsensitive, range: content.index(content.startIndex, offsetBy: offset)..<content.endIndex) {
                let start = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(range.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex
                found.append(SearchResult(
                    chapterIndex: item.index,
                    chapterTitle: item.title,
                    position: range.lowerBound.utf16Offset(in: content),
                    preview: "...\(content[start..<end])..."
                ))
                if found.count >= 500 { return found }
                offset = content.distance(from: content.startIndex, to: range.upperBound)
            }
        }
        return found
    }
}

@MainActor
class SearchContentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var results: [SearchResult] = []
    @Published var searchHistory: [String] = []

    private let book: Book
    private var chapters: [BookChapter] = []

    init(book: Book) {
        self.book = book
        loadChapters()
        loadHistory()
    }

    private func loadChapters() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        chapters = (try? context.fetch(request)) ?? []
    }

    private func loadHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "searchContentHistory") {
            searchHistory = history
        }
    }

    func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        results = []
        let keyword = searchText

        // 缓存优先：正文取自已缓存章节文件；本地书籍正文天然可用，整本切片后兜底
        let isLocal = book.origin == "local"
        let bookPath = book.bookUrl
        let items: [ChapterScanItem] = chapters.map {
            ChapterScanItem(index: Int($0.index), title: $0.title, cachePath: $0.cachePath)
        }
        let hits: [SearchResult] = await Task.detached(priority: .userInitiated) {
            var localSlices: [String] = []
            if isLocal {
                localSlices = ChapterContentScan.splitLocalChapters(path: bookPath)
            }
            return ChapterContentScan.scan(keyword: keyword, items: items, localSlices: localSlices)
        }.value

        results = hits
        isSearching = false
        saveHistory()
    }

    private func saveHistory() {
        if !searchHistory.contains(searchText) {
            searchHistory.insert(searchText, at: 0)
            if searchHistory.count > 10 { searchHistory.removeLast() }
            UserDefaults.standard.set(searchHistory, forKey: "searchContentHistory")
        }
    }
}