//
//  DiscoverTabView.swift
//  Legado-iOS
//
//  发现tab（对齐真版）：站点分组列表 → 源内浏览页
//  源内浏览页顶栏：返回 | 源名 | 搜索 切换；分类chip顿号分隔，选中红色
//

import SwiftUI

// MARK: - 发现tab（顶栏与书架一致，内容区为站点浏览）

struct DiscoverTabView: View {
    var body: some View { DiscoverHomeView() }
}

// MARK: - 发现主页：按内容类型分组的站点列表

struct DiscoverHomeView: View {
    @StateObject private var store = XBSSourceStore.shared

    private var enabledSources: [XBSSource] {
        store.sources.filter { $0.enabled }
    }

    private var textSources: [XBSSource] { enabledSources.filter { $0.sourceType == "text" } }
    private var imageSources: [XBSSource] { enabledSources.filter { $0.sourceType == "image" } }
    private var audioSources: [XBSSource] { enabledSources.filter { $0.sourceType == "audio" } }
    private var videoSources: [XBSSource] { enabledSources.filter { $0.sourceType == "video" } }

    var body: some View {
        Group {
            if enabledSources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有可用站点")
                        .font(.headline)
                    Text("先在书架右上角「＋」导入 .xbs 书源\n再回到这里按站点逛书")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    sourceSection("文本/小说", textSources)
                    sourceSection("图片/漫画/壁纸", imageSources)
                    sourceSection("音频/听书", audioSources)
                    sourceSection("视频/电影/电视剧", videoSources)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func sourceSection(_ title: String, _ sources: [XBSSource]) -> some View {
        if !sources.isEmpty {
            Section(header: Text(title)) {
                ForEach(sources, id: \.alias) { source in
                    NavigationLink {
                        SourceBrowsePage(source: source)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.sourceName)
                                .foregroundColor(.primary)
                            if let remark = source.config.string("remark"), !remark.isEmpty {
                                Text(remark)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 源内浏览页（真版：返回 | 源名 | 搜索 切换 + 分类筛选 + 书籍列表）

struct SourceBrowsePage: View {
    @State var source: XBSSource
    @State private var categories: [XBSEngine.XBSCategory] = []
    @State private var selectedCategory: XBSEngine.XBSCategory?
    @State private var books: [XBSBook] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var searchKeyword = ""
    @State private var searchResults: [XBSBook] = []
    @State private var showSearchField = false
    @State private var showingSourcePicker = false
    @State private var loadGeneration = UUID()
    @State private var filterGroups: [XBSEngine.XBSFilterGroup] = []
    @State private var filters: [String: String] = [:]

    private var browseKey: String {
        source.alias + "|" + (selectedCategory?.id ?? "") + "|" + filters.keys.sorted().map { $0 + "=" + (filters[$0] ?? "") }.joined(separator: "&")
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSearchField {
                searchBar
            }
            filterChips
            bookList
        }
        .navigationTitle(source.sourceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        withAnimation { showSearchField.toggle() }
                    } label: {
                        Text(showSearchField ? "浏览" : "搜索")
                    }
                    Button {
                        showingSourcePicker = true
                    } label: {
                        Text("切换")
                    }
                }
                .font(.subheadline)
            }
        }
        .task(id: source.alias) { configureSource() }
        .task(id: browseKey) { if source.action("bookWorld") != nil { await reload() } }
        .sheet(isPresented: $showingSourcePicker) { sourcePicker }
        .onChange(of: selectedCategory) { _ in configureFilters() }
    }

    // MARK: 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("搜索 \(source.sourceName)", text: $searchKeyword)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !searchKeyword.isEmpty {
                    Button {
                        searchKeyword = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(9)

            Button {
                Task { await search() }
            } label: {
                if isSearching {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("搜索").font(.subheadline)
                }
            }
            .disabled(searchKeyword.isEmpty || isSearching)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sourcePicker: some View {
        NavigationStack {
            List(XBSSourceStore.shared.sources.filter { $0.enabled }) { item in
                Button(item.sourceName) { source = item; showingSourcePicker = false }
                    .foregroundColor(item.alias == source.alias ? .accentColor : .primary)
            }
            .listStyle(.plain)
            .navigationTitle("切换站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("取消") { showingSourcePicker = false } }
        }
    }

    private func configureSource() {
        searchResults = []
        errorMessage = nil
        categories = XBSEngine.shared.bookWorldCategories(source: source)
        selectedCategory = categories.first
        showSearchField = source.action("bookWorld") == nil
        configureFilters()
    }

    private func configureFilters() {
        filterGroups = XBSEngine.shared.bookWorldFilters(source: source, category: selectedCategory)
        filters = Dictionary(uniqueKeysWithValues: filterGroups.map { ($0.key, $0.options.first?.value ?? "") })
    }

    @ViewBuilder
    private var filterChips: some View {
        if !showSearchField {
            VStack(alignment: .leading, spacing: 12) {
                categoryOptions
                ForEach(filterGroups) { group in filterOptions(group) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var categoryOptions: some View {
        FlowLayout(spacing: 14) {
            ForEach(categories) { category in
                Button(category.name) { selectedCategory = category }
                    .font(.system(size: 14))
                    .foregroundColor(category == selectedCategory ? XSGTheme.brandRed : .primary)
            }
        }
    }

    private func filterOptions(_ group: XBSEngine.XBSFilterGroup) -> some View {
        FlowLayout(spacing: 12) {
            ForEach(group.options) { option in
                Button(option.name) { filters[group.key] = option.value }
                    .font(.system(size: 13))
                    .foregroundColor(filters[group.key] == option.value ? XSGTheme.brandRed : .secondary)
            }
        }
    }

    // MARK: 书籍列表（真版行：封面 + 红书名 + 作者·分类·状态 + 简介）

    private var bookList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                let list = showSearchField ? searchResults : books
                if (showSearchField ? isSearching : isLoading) && list.isEmpty {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if list.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(errorMessage ?? (showSearchField ? "输入书名或作者搜索" : "该分类下暂无书籍"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    if errorMessage != nil {
                        Button("重试") { Task { if showSearchField { await search() } else { await reload() } } }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(list, id: \.detailUrl) { book in
                        NavigationLink {
                            XBSBookDetailView(initialBook: book)
                        } label: {
                            SourceBookRow(book: book)
                        }
                        .buttonStyle(.plain)
                    }

                    if !showSearchField && hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear { Task { await loadMore() } }
                    }

                    if let errorMessage, !showSearchField {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    // MARK: 数据

    private func reload() async {
        loadGeneration = UUID()
        isLoading = false
        errorMessage = nil
        page = 1
        books.removeAll()
        hasMore = true
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        do {
            let newBooks = try await XBSEngine.shared.bookWorld(
                source: source,
                category: selectedCategory,
                page: page,
                filters: filters
            )
            guard generation == loadGeneration, !Task.isCancelled else { return }
            let existing = Set(books.map { $0.detailUrl })
            books.append(contentsOf: newBooks.filter { !existing.contains($0.detailUrl) })
            page += 1
            hasMore = !newBooks.isEmpty
            errorMessage = nil
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = "加载失败：\(error.localizedDescription)"
            hasMore = false
        }
    }

    private func search() async {
        let keyword = searchKeyword.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        let alias = source.alias
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let results = try await XBSEngine.shared.search(source: source, keyword: keyword)
            guard alias == source.alias, keyword == searchKeyword.trimmingCharacters(in: .whitespaces) else { return }
            searchResults = results
            if results.isEmpty { errorMessage = "没有找到相关书籍" }
        } catch {
            guard alias == source.alias else { return }
            errorMessage = "搜索失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 源内书籍行

struct SourceBookRow: View {
    let book: XBSBook
    @State private var imageData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(url: book.cover)
                .frame(width: 60, height: 82)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 0) {
                    if !book.author.isEmpty {
                        Text(book.author).foregroundColor(.secondary)
                        separator
                    }
                    if let cat = book.cat, !cat.isEmpty {
                        Text(cat).foregroundColor(.secondary)
                        separator
                    }
                    if let status = book.status, !status.isEmpty {
                        Text(status).foregroundColor(.secondary)
                    }
                }
                .font(.caption)

                if let desc = book.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }

    private var separator: some View {
        Text(" · ")
            .foregroundColor(.secondary.opacity(0.5))
    }
}
