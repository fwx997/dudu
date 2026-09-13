//
//  ReaderViewModel.swift
//  Legado-iOS
//
//  阅读器 ViewModel
//

import Foundation
import SwiftUI
import CoreData

@MainActor
class ReaderViewModel: ObservableObject {
    // MARK: - Published 属性
    @Published var chapterContent: String?
    @Published var currentChapter: BookChapter?
    @Published var currentChapterIndex: Int = 0
    @Published var totalChapters: Int = 0
    @Published var chapters: [BookChapter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cacheProgressText: String?
    @Published var currentBook: Book?
    @Published var durChapterPos: Int32 = 0
    @Published var theme: ReaderTheme = .light
    @Published var useReplaceRule: Bool = true
    
    // MARK: - 分页状态
    @Published var currentPageIndex: Int = 0 {
        didSet {
            if oldValue != currentPageIndex {
                updatePagingProgressIfNeeded()
            }
        }
    }
    @Published var totalPages: Int = 0
    
    // MARK: - 阅读设置
    @Published var fontSize: CGFloat = 18 {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "reader.fontSize")
        }
    }
    @Published var lineSpacing: CGFloat = 8 {
        didSet {
            UserDefaults.standard.set(Double(lineSpacing), forKey: "reader.lineSpacing")
        }
    }
    @Published var pagePadding: EdgeInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16) {
        didSet {
            UserDefaults.standard.set(Double(pagePadding.leading), forKey: "reader.pageMargin")
        }
    }
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    
    // MARK: - 新增阅读设置
    @Published var paragraphSpacing: CGFloat = 12
    @Published var letterSpacing: CGFloat = 0
    @Published var fontName: String = "" {
        didSet {
            UserDefaults.standard.set(fontName, forKey: "reader.fontName")
        }
    }

    /// 香色闺阁式字体：空 = 系统默认，否则按 PostScript 名取自定义字体
    var readerFont: Font {
        fontName.isEmpty ? .system(size: fontSize) : .custom(fontName, size: fontSize)
    }
    
    // MARK: - 私有属性
    private var ruleEngine: RuleEngine = RuleEngine()
    private var loadTask: Task<Void, Never>?
    let cacheManager = ChapterCacheManager()

    init() {
        loadReaderPreferences()
    }

    private func loadReaderPreferences() {
        let defaults = UserDefaults.standard

        let storedFontSize = defaults.double(forKey: "reader.fontSize")
        if storedFontSize > 0 {
            fontSize = CGFloat(storedFontSize)
        }

        let storedLineSpacing = defaults.double(forKey: "reader.lineSpacing")
        if storedLineSpacing > 0 {
            lineSpacing = CGFloat(storedLineSpacing)
        }

        let storedMargin = defaults.double(forKey: "reader.pageMargin")
        if storedMargin > 0 {
            let margin = CGFloat(storedMargin)
            pagePadding = EdgeInsets(top: 20, leading: margin, bottom: 20, trailing: margin)
        }

        fontName = defaults.string(forKey: "reader.fontName") ?? ""

        if let storedTheme = defaults.string(forKey: "reader.theme") {
            applyTheme(themeFromStorage(storedTheme))
        }
    }

    private func themeFromStorage(_ raw: String) -> ReaderTheme {
        switch raw {
        case "暗色":
            return .dark
        case "羊皮纸":
            return .sepia
        case "护眼":
            return .eyeProtection
        default:
            return .light
        }
    }
    
    // MARK: - 颜色主题
    enum ReaderTheme {
        case light
        case dark
        case sepia
        case eyeProtection
        
        var backgroundColor: Color {
            switch self {
            case .light: return Color.white
            case .dark: return Color.black
            case .sepia: return Color(red: 0.96, green: 0.91, blue: 0.83)
            case .eyeProtection: return Color(red: 0.75, green: 0.84, blue: 0.71)
            }
        }
        
        var textColor: Color {
            switch self {
            case .light: return Color.black
            case .dark: return Color.white
            case .sepia: return Color(red: 0.33, green: 0.28, blue: 0.22)
            case .eyeProtection: return Color.black
            }
        }
    }
    
    // MARK: - 加载书籍
    func loadBook(_ book: Book) {
        loadTask?.cancel()
        currentBook = book
        isLoading = true

        loadTask = Task {
            do {
                try Task.checkCancellation()

                applyReadConfig(book)

                // 加载目录
                try await loadChapters(book: book)
                
                // 加载当前章节
                let chapterIndex = Int(book.durChapterIndex)
                if chapterIndex < chapters.count {
                    currentChapterIndex = chapterIndex
                    durChapterPos = book.durChapterPos
                    let restorePage = max(0, Int(book.durChapterPos))
                    try await loadChapter(at: chapterIndex, restorePageIndex: restorePage)
                }
                
                isLoading = false
            } catch is CancellationError {
                isLoading = false
            } catch {
                errorMessage = "加载失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - 加载目录
    private func loadChapters(book: Book) async throws {
        let request = BookChapter.fetchRequest(byBookId: book.bookId)
        
        let context = CoreDataStack.shared.viewContext
        var chapters = try context.fetch(request)

        if chapters.isEmpty, !book.isLocal {
            // 香色闺阁站点书籍：走 XBS 引擎
            if book.origin.hasPrefix("xbs://") {
                let alias = String(book.origin.dropFirst("xbs://".count))
                guard let source = XBSSourceStore.shared.source(alias: alias) else {
                    throw ReaderError.noSource
                }
                let tocURL = book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl
                let xbsChapters = try await XBSEngine.shared.chapterList(source: source, url: tocURL)
                guard !xbsChapters.isEmpty else {
                    throw ReaderError.noChapters
                }

                for (index, web) in xbsChapters.enumerated() {
                    let chapter = BookChapter.create(
                        in: context,
                        bookId: book.bookId,
                        url: web.url,
                        index: Int32(index),
                        title: web.title
                    )
                    chapter.book = book
                    chapter.sourceId = book.origin
                }

                book.totalChapterNum = Int32(xbsChapters.count)
                try CoreDataStack.shared.save()
                chapters = try context.fetch(request)
            } else {
                guard let sourceId = UUID(uuidString: book.origin) else {
                    throw ReaderError.noSource
                }

                let sourceRequest: NSFetchRequest<BookSource> = BookSource.fetchRequest()
                sourceRequest.fetchLimit = 1
                sourceRequest.predicate = NSPredicate(format: "sourceId == %@", sourceId as CVarArg)
                guard let source = try context.fetch(sourceRequest).first else {
                    throw ReaderError.noSource
                }

                let webChapters = try await WebBook.getChapterList(source: source, book: book)
                guard !webChapters.isEmpty else {
                    throw ReaderError.noChapters
                }

                for web in webChapters {
                    let chapter = BookChapter.create(
                        in: context,
                        bookId: book.bookId,
                        url: web.url,
                        index: Int32(web.index),
                        title: web.title
                    )
                    chapter.book = book
                    chapter.sourceId = source.sourceId.uuidString
                    chapter.isVIP = web.isVip
                }

                book.totalChapterNum = Int32(webChapters.count)
                try CoreDataStack.shared.save()

                chapters = try context.fetch(request)
            }
        }

        self.chapters = chapters
        self.totalChapters = chapters.count

        if chapters.isEmpty {
            throw ReaderError.noChapters
        }
    }
    
    // MARK: - 加载章节
    func loadChapter(at index: Int, restorePageIndex: Int? = nil) async throws {
        guard index >= 0 && index < chapters.count else {
            throw ReaderError.invalidChapterIndex
        }
        
        isLoading = true
        currentChapterIndex = index
        currentChapter = chapters[index]
        if let restorePageIndex {
            currentPageIndex = max(0, restorePageIndex)
            durChapterPos = Int32(currentPageIndex)
        } else {
            currentPageIndex = 0
            durChapterPos = 0
        }
        
        do {
            // 尝试从缓存加载
            if let cachedContent = try? await loadCachedChapter(chapters[index]) {
                chapterContent = applyReplaceRulesIfNeeded(cachedContent, chapter: chapters[index])
                isLoading = false
                return
            }
            
            // 从网络加载
            let content = try await fetchChapterContent(chapters[index])
            chapterContent = applyReplaceRulesIfNeeded(content, chapter: chapters[index])
            
            // 缓存章节
            try await cacheChapter(chapters[index], content: content)
            
            isLoading = false
            
            // 预加载前后章节
            if let book = currentBook {
                cacheManager.preloadAroundChapter(
                    index: index,
                    chapters: chapters,
                    book: book
                )
            }
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    /// 刷新当前章节：清掉缓存标记后强制重新抓取
    func reloadCurrentChapter() async {
        guard let chapter = currentChapter else { return }
        chapter.isCached = false
        chapter.cachePath = nil
        try? CoreDataStack.shared.save()
        do {
            try await loadChapter(at: currentChapterIndex)
        } catch {
            errorMessage = "刷新失败：\(error.localizedDescription)"
        }
    }

    /// 缓存全本（对齐香色闺阁的全本下载）
    func cacheEntireBook() async {
        guard let book = currentBook else { return }
        cacheProgressText = "开始缓存 0/\(chapters.count)"
        await cacheManager.cacheAllChapters(chapters: chapters, book: book) { done, total in
            Task { @MainActor in
                self.cacheProgressText = "缓存中 \(done)/\(total)"
            }
        }
        cacheProgressText = "全本缓存完成"
        try? CoreDataStack.shared.save()
    }

    // MARK: - 章节导航
    func prevChapter() async {
        guard currentChapterIndex > 0 else { return }
        do {
            try await loadChapter(at: currentChapterIndex - 1)
            saveProgress()
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }
    
    func nextChapter() async {
        guard currentChapterIndex < totalChapters - 1 else { return }
        do {
            try await loadChapter(at: currentChapterIndex + 1)
            saveProgress()
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }
    
    func jumpToChapter(_ index: Int) {
        guard index >= 0 && index < totalChapters else { return }
        
        Task {
            try? await loadChapter(at: index)
            saveProgress()
        }
    }

    func loadChapter() async {
        do {
            try await loadChapter(at: currentChapterIndex)
        } catch {
            errorMessage = "加载章节失败：\(error.localizedDescription)"
        }
    }

    func loadChapterList() async {
        guard let book = currentBook else { return }
        do {
            try await loadChapters(book: book)
        } catch {
            errorMessage = "加载目录失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 阅读配置
    func applyReadConfig(_ book: Book) {
        let config = book.readConfigObj

        seedGlobalPageAnimationIfNeeded(from: config)

        // 应用主题
        applyTheme(themeFromStorage(UserDefaults.standard.string(forKey: "reader.theme") ?? "亮色"))

        useReplaceRule = config.useReplaceRule
    }

    private func seedGlobalPageAnimationIfNeeded(from config: ReadConfig) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "pageAnimation") == nil else {
            return
        }
        defaults.set(Self.pageAnimationRawValue(from: config.pageAnim), forKey: "pageAnimation")
    }

    private static func pageAnimationRawValue(from configValue: Int32) -> String {
        let animation = PageAnimation(rawValue: configValue) ?? .cover
        switch animation {
        case .cover:
            return PageAnimationType.cover.rawValue
        case .simulation:
            return PageAnimationType.simulation.rawValue
        case .slide:
            return PageAnimationType.slide.rawValue
        case .scroll:
            return PageAnimationType.scroll.rawValue
        }
    }
    
    func applyTheme(_ theme: ReaderTheme) {
        self.theme = theme
        backgroundColor = theme.backgroundColor
        textColor = theme.textColor

        UserDefaults.standard.set(storageThemeValue(theme), forKey: "reader.theme")
    }

    private func storageThemeValue(_ theme: ReaderTheme) -> String {
        switch theme {
        case .light:
            return "亮色"
        case .dark:
            return "暗色"
        case .sepia:
            return "羊皮纸"
        case .eyeProtection:
            return "护眼"
        }
    }

    private func applyReplaceRulesIfNeeded(_ text: String, chapter: BookChapter) -> String {
        guard let book = currentBook else { return text }
        if !useReplaceRule {
            return text
        }
        return ReplaceEngineEnhanced.shared.applyForReader(
            text: text,
            bookId: book.bookId,
            chapterId: chapter.chapterId,
            context: CoreDataStack.shared.viewContext
        )
    }

    func turnToNextPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex + 1 < totalPages else { return false }
        currentPageIndex += 1
        return true
    }

    func turnToPreviousPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex > 0 else { return false }
        currentPageIndex -= 1
        return true
    }

    private func updatePagingProgressIfNeeded() {
        let clamped = max(0, currentPageIndex)
        let newPos = Int32(clamped)
        if durChapterPos != newPos {
            durChapterPos = newPos
        }
        saveProgress()
    }

    func setTheme(_ theme: ReaderTheme) async {
        applyTheme(theme)
    }

    func setFontSize(_ size: CGFloat) async {
        let clamped = min(max(size, 8), 32)
        fontSize = clamped
    }
    
    // MARK: - 缓存管理
    private func loadCachedChapter(_ chapter: BookChapter) async throws -> String {
        // 从文件系统加载缓存的章节内容
        guard chapter.isCached, let cachePath = chapter.cachePath, !cachePath.isEmpty else {
            throw ReaderError.notCached
        }
        
        let cacheURL: URL
        if cachePath.hasPrefix("/") {
            cacheURL = URL(fileURLWithPath: cachePath)
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            cacheURL = documents.appendingPathComponent("chapters").appendingPathComponent(cachePath)
        }
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            throw ReaderError.notCached
        }
        
        return try String(contentsOf: cacheURL, encoding: .utf8)
    }
    
    private func fetchChapterContent(_ chapter: BookChapter) async throws -> String {
        guard let book = currentBook else {
            throw ReaderError.noBook
        }

        // 本地书籍直接返回 TXT 切片内容
        if book.origin == "local" {
            return try await loadLocalChapterContent(chapter)
        }
        // 香色闺阁站点书籍：走 XBS 引擎
        if book.origin.hasPrefix("xbs://") {
            let alias = String(book.origin.dropFirst("xbs://".count))
            guard let source = XBSSourceStore.shared.source(alias: alias) else {
                throw ReaderError.noSource
            }
            return try await XBSEngine.shared.chapterContent(source: source, url: chapter.chapterUrl)
        }

        // 网络书籍：通过 WebBook 从书源获取
        guard let sourceId = UUID(uuidString: book.origin) else {
            throw ReaderError.noSource
        }
        
        // 查找对应书源
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "sourceId == %@", sourceId as CVarArg)
        
        guard let source = try? CoreDataStack.shared.viewContext.fetch(request).first else {
            throw ReaderError.noSource
        }
        
        return try await WebBook.getContent(source: source, book: book, chapter: chapter)
    }
    
    /// 加载本地 TXT 书籍的章节内容
    private func loadLocalChapterContent(_ chapter: BookChapter) async throws -> String {
        guard let book = currentBook else { throw ReaderError.noBook }
        
        let fileURL = URL(fileURLWithPath: book.bookUrl)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        
        // 通过章节索引找到对应的内容段
        // 使用与 LocalBookViewModel 相同的分章逻辑
        let chapterPatterns = [
            #"^第[零一二三四五六七八九十百千万0-9]+[章回卷节部篇]"#,
            #"^第[0-9]+章"#,
            #"^Chapter [0-9]+"#,
            #"^\s*第[0-9一二三四五六七八九十]+节"#
        ]
        
        var chapters: [(title: String, content: String)] = []
        var currentTitle: String?
        var currentContent = ""
        
        for line in content.components(separatedBy: .newlines) {
            var isChapterStart = false
            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            
            if isChapterStart {
                if let title = currentTitle { chapters.append((title, currentContent)) }
                currentTitle = line.trimmingCharacters(in: .whitespaces)
                currentContent = ""
            } else {
                currentContent += line + "\n"
            }
        }
        if let title = currentTitle { chapters.append((title, currentContent)) }
        if chapters.isEmpty { return content }
        
        let idx = Int(chapter.index)
        guard idx >= 0 && idx < chapters.count else { throw ReaderError.notCached }
        return chapters[idx].content.trimmingCharacters(in: .whitespaces)
    }
    
    private func cacheChapter(_ chapter: BookChapter, content: String) async throws {
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
        try? CoreDataStack.shared.save()
    }
    
    // MARK: - 保存进度
    func saveProgress() {
        guard let book = currentBook else { return }
        
        book.durChapterIndex = Int32(currentChapterIndex)
        book.durChapterTime = Int64(Date().timeIntervalSince1970)
        book.durChapterPos = durChapterPos
        
        if let chapter = currentChapter {
            book.durChapterTitle = chapter.title
        }
        
        try? CoreDataStack.shared.save()
    }

    func saveReadingProgress() async {
        saveProgress()
    }
    
}

extension ReaderViewModel {
    var currentContent: String? {
        get { chapterContent }
        set { chapterContent = newValue }
    }

    var chapterList: [BookChapter] {
        chapters
    }
}

enum ReaderError: LocalizedError {
    case noChapters
    case invalidChapterIndex
    case notCached
    case networkFailure
    case noBook
    case noSource
    case parseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noChapters: return "没有章节"
        case .invalidChapterIndex: return "无效的章节索引"
        case .notCached: return "章节未缓存"
        case .networkFailure: return "网络加载失败"
        case .noBook: return "未找到书籍"
        case .noSource: return "未找到书源"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        }
    }
}
// MARK: - 阅读设置面板（香色闺阁式底部面板）
struct ReaderSettingsView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Binding var isPresented: Bool
    var onOpenChapterList: (() -> Void)? = nil

    @AppStorage("pageAnimation") private var pageAnimationRaw: String = PageAnimationType.cover.rawValue
    @State private var brightness: Double = Double(UIScreen.main.brightness)
    @State private var showingFullSettings = false

    private let fontOptions: [(title: String, postScript: String)] = [
        ("系统默认", ""),
        ("宋体", "Songti SC"),
        ("楷体", "Kaiti SC"),
        ("圆体", "Yuanti SC"),
        ("黑体", "Heiti SC"),
    ]

    private let themes: [(String, ReaderViewModel.ReaderTheme)] = [
        ("亮色", .light),
        ("羊皮纸", .sepia),
        ("护眼", .eyeProtection),
        ("夜间", .dark),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 章节导航
            HStack(spacing: 12) {
                navButton("上一章", "chevron.left.2") {
                    Task { await viewModel.prevChapter() }
                }
                navButton("目录", "list.bullet") {
                    isPresented = false
                    onOpenChapterList?()
                }
                navButton("下一章", "chevron.right.2") {
                    Task { await viewModel.nextChapter() }
                }
            }

            Divider()

            // 主题
            HStack(spacing: 14) {
                Text("背景")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(themes, id: \.1) { item in
                    Button {
                        viewModel.applyTheme(item.1)
                    } label: {
                        Circle()
                            .fill(item.1.backgroundColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(
                                    viewModel.theme == item.1 ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: viewModel.theme == item.1 ? 2.5 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.0)
                }
                Spacer()
            }

            // 字号
            HStack(spacing: 14) {
                Text("字号")
                    .font(.caption)
                    .foregroundColor(.secondary)
                roundButton("A-") { viewModel.fontSize = max(12, viewModel.fontSize - 1) }
                Text("\(Int(viewModel.fontSize))")
                    .font(.subheadline)
                    .frame(minWidth: 28)
                roundButton("A+") { viewModel.fontSize = min(40, viewModel.fontSize + 1) }
                Spacer()
            }

            // 字体
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(fontOptions, id: \.postScript) { option in
                        Button {
                            viewModel.fontName = option.postScript
                        } label: {
                            Text(option.title)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.fontName == option.postScript ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                                .foregroundColor(viewModel.fontName == option.postScript ? .accentColor : .primary)
                                .cornerRadius(999)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 行距预设（对齐香色闺阁排版预设：紧凑/默认/宽松）
            HStack(spacing: 14) {
                Text("行距")
                    .font(.caption)
                    .foregroundColor(.secondary)
                spacingChip("紧凑", 6)
                spacingChip("标准", 10)
                spacingChip("宽松", 16)
                Spacer()
            }

            // 翻页方式
            HStack(spacing: 14) {
                Text("翻页")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $pageAnimationRaw) {
                    Text("覆盖").tag(PageAnimationType.cover.rawValue)
                    Text("平移").tag(PageAnimationType.slide.rawValue)
                    Text("仿真").tag(PageAnimationType.simulation.rawValue)
                    Text("滚动").tag(PageAnimationType.scroll.rawValue)
                }
                .pickerStyle(.segmented)
            }

            // 亮度
            HStack(spacing: 10) {
                Image(systemName: "sun.min")
                    .foregroundColor(.secondary)
                Slider(value: $brightness, in: 0.05...1)
                    .onChange(of: brightness) { newValue in
                        UIScreen.main.brightness = CGFloat(newValue)
                    }
            }

            // 更多设置
            Button {
                showingFullSettings = true
            } label: {
                Text("更多阅读设置")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 12, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingFullSettings) {
            ReaderSettingsFullView()
        }
        .onDisappear {
            UIScreen.main.brightness = CGFloat(brightness)
        }
    }

    private func navButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func roundButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(width: 44, height: 30)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func spacingChip(_ title: String, _ value: CGFloat) -> some View {
        Button {
            viewModel.lineSpacing = value
        } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(abs(viewModel.lineSpacing - value) < 0.5 ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                .foregroundColor(abs(viewModel.lineSpacing - value) < 0.5 ? .accentColor : .primary)
                .cornerRadius(999)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 目录列表
struct ChapterListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let book: Book
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var reversed = false

    /// 搜索过滤 + 倒序后的展示列表（保留原始章节序号）
    private var displayChapters: [(offset: Int, element: BookChapter)] {
        var list = Array(viewModel.chapters.enumerated())
        if !searchText.isEmpty {
            list = list.filter { $0.element.title.localizedCaseInsensitiveContains(searchText) }
        }
        if reversed {
            list.reverse()
        }
        return list
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(displayChapters, id: \.element.chapterId) { index, chapter in
                    Button(action: {
                        viewModel.jumpToChapter(index)
                        dismiss()
                    }) {
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 40)

                            Text(chapter.title)
                                .lineLimit(2)
                                .foregroundColor(index == viewModel.currentChapterIndex ? .accentColor : .primary)

                            Spacer()

                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }

                            if chapter.isCached {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索章节标题")
            .navigationTitle("目录 \(viewModel.chapters.count)章")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        reversed.toggle()
                    } label: {
                        Label(reversed ? "正序" : "倒序", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
