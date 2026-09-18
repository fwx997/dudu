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
    @State private var showingSearch = false
    @State private var showingAddMenu = false
    @StateObject private var store = XBSSourceStore.shared

    var body: some View {
        VStack(spacing: 0) {
            XSGBTopTabs(
                onFolder: {},
                onSearch: { showingSearch = true },
                onAdd: { showingAddMenu = true }
            )
            .disabled(false)

            DiscoverHomeView()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSearch) {
            NavigationStack { SearchResultView() }
        }
        .confirmationDialog("添加", isPresented: $showingAddMenu, titleVisibility: .visible) {
            Button("新建站点") {}
            Button("网络导入书源") {}
            Button("剪贴板导入书源") {}
            Button("取消", role: .cancel) {}
        }
        .task { store.load() }
    }
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
                .listStyle(.insetGrouped)
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
    let source: XBSSource
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        withAnimation { showSearchField.toggle() }
                    } label: {
                        Text(showSearchField ? "浏览" : "搜索")
                    }
                    Button {
                        // 切换：回到站点列表
                    } label: {
                        Text("切换")
                    }
                }
                .font(.subheadline)
            }
        }
        .task {
            categories = XBSEngine.shared.bookWorldCategories(source: source)
            selectedCategory = categories.first
            await reload()
        }
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

    // MARK: 分类筛选（真版：顿号/间隔点分隔，选中红色）

    @ViewBuilder
    private var filterChips: some View {
        if !showSearchField && !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(categories) { category in
                        let selected = category == selectedCategory
                        Button {
                            selectedCategory = category
                            Task { await reload() }
                        } label: {
                            Text(category.name)
                                .font(.subheadline)
                                .foregroundColor(selected ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        if category != categories.last {
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.5))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
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
                        Text(showSearchField ? "没有找到相关书籍" : "该分类下暂无书籍")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
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
        page = 1
        books.removeAll()
        hasMore = true
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let newBooks = try await XBSEngine.shared.bookWorld(
                source: source,
                category: selectedCategory,
                page: page
            )
            let existing = Set(books.map { $0.detailUrl })
            books.append(contentsOf: newBooks.filter { !existing.contains($0.detailUrl) })
            page += 1
            hasMore = !newBooks.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            hasMore = false
        }
    }

    private func search() async {
        let keyword = searchKeyword.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await XBSEngine.shared.search(source: source, keyword: keyword)
        } catch {
            searchResults = []
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
                .frame(width: 62, height: 84)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(5)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.name)
                    .font(.body)
                    .foregroundColor(.accentColor)
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
