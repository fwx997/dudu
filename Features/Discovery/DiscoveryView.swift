//
//  DiscoveryView.swift
//  Legado-iOS
//
//  发现页（香色闺阁「书世界」）：站点/分类切换浏览，数据来自 XBS 站点的 bookWorld 配置
//

import SwiftUI
import CoreData

struct DiscoveryView: View {
    @StateObject private var store = XBSSourceStore.shared
    @State private var selectedSourceAlias: String?
    @State private var categories: [XBSEngine.XBSCategory] = []
    @State private var selectedCategory: XBSEngine.XBSCategory?
    @State private var books: [XBSBook] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = true
    @State private var loadErrorMessage: String?

    // 书单
    enum DiscoveryMode: String, CaseIterable {
        case bookWorld = "书世界"
        case shudan = "书单"
    }
    @State private var mode: DiscoveryMode
    @State private var shudanKeyword = ""
    @State private var shudanResults: [XBSEngine.XBSShudan] = []
    @State private var shudanSearching = false
    @State private var shudanError: String?
    @State private var selectedShudan: XBSEngine.XBSShudan?
    @State private var showingShudanDetail = false

    init(initialMode: DiscoveryMode = .bookWorld) {
        _mode = State(initialValue: initialMode)
    }

    private var bookWorldSources: [XBSSource] {
        store.sources.filter { $0.enabled && $0.action("bookWorld") != nil }
    }

    private var selectedSource: XBSSource? {
        bookWorldSources.first { $0.alias == selectedSourceAlias } ?? bookWorldSources.first
    }

    var body: some View {
        Group {
            if bookWorldSources.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    RSSSubscriptionView()
                } label: {
                    Label("RSS订阅", systemImage: "dot.radiowaves.left.and.right")
                }
            }
        }
        .task {
            if books.isEmpty && !isLoading {
                await switchSource(selectedSource)
            }
        }
        .refreshable {
            await reload()
        }
        .sheet(isPresented: $showingShudanDetail) {
            if let shudan = selectedShudan {
                NavigationStack { XBSShudanDetailView(shudan: shudan) }
            }
        }
    }

    // MARK: - 主内容

    private var contentView: some View {
        VStack(spacing: 0) {
            // 书世界 / 书单 切换
            Picker("", selection: $mode) {
                ForEach(DiscoveryMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if mode == .bookWorld {
                bookWorldContent
            } else {
                shudanContent
            }
        }
    }

    // MARK: - 书世界

    private var bookWorldContent: some View {
        VStack(spacing: 0) {
            // 站点行
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(bookWorldSources) { source in
                        chip(title: source.sourceName,
                             isSelected: source.alias == selectedSource?.alias) {
                            Task { await switchSource(source) }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // 分类行
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories) { category in
                            chip(title: category.name,
                                 isSelected: category == selectedCategory) {
                                selectedCategory = category
                                Task { await reload() }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }

            // 书籍网格
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 16) {
                    ForEach(books, id: \.detailUrl) { book in
                        NavigationLink {
                            XBSBookDetailView(initialBook: book)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                BookCoverView(url: book.cover)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3 / 4, contentMode: .fill)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)

                                Text(book.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                Text(book.author.isEmpty ? book.sourceName : book.author)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if hasMore && !books.isEmpty {
                        Color.clear
                            .frame(height: 1)
                            .onAppear { Task { await loadMore() } }
                    }
                }
                .padding()

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    // MARK: - 书单

    private var shudanContent: some View {
        VStack(spacing: 0) {
            // 书单搜索栏
            HStack(spacing: 8) {
                TextField("搜索书单", text: $shudanKeyword)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .submitLabel(.search)
                    .onSubmit { Task { await searchShudan() } }

                Button {
                    Task { await searchShudan() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .disabled(shudanKeyword.isEmpty || shudanSearching)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if shudanSearching {
                Spacer()
                ProgressView("正在搜索书单...")
                Spacer()
            } else if shudanResults.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(shudanError ?? "输入关键词搜索书单")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(shudanResults) { shudan in
                    Button {
                        selectedShudan = shudan
                        showingShudanDetail = true
                    } label: {
                        HStack(spacing: 12) {
                            BookCoverView(url: shudan.cover)
                                .frame(width: 52, height: 70)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(shudan.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)
                                if let desc = shudan.desc, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Text(shudan.sourceName)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func searchShudan() async {
        let keyword = shudanKeyword.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }
        shudanSearching = true
        shudanError = nil
        defer { shudanSearching = false }

        var all: [XBSEngine.XBSShudan] = []
        var firstError: String?
        let sources = bookWorldSources.filter { $0.action("searchShudan") != nil }
        await withTaskGroup(of: [XBSEngine.XBSShudan].self) { group in
            for source in sources {
                group.addTask {
                    (try? await XBSEngine.shared.searchShudan(source: source, keyword: keyword)) ?? []
                }
            }
            for await partial in group {
                all.append(contentsOf: partial)
            }
        }
        shudanResults = all
        shudanError = all.isEmpty ? (firstError ?? "没有找到书单") : nil
    }

    // MARK: - 空态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有可浏览的站点")
                .font(.headline)
            Text("导入带「书世界/分类」配置的 .xbs 书源后\n可以在这里按分类逛书")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 数据

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color(.systemGray6)))
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .lineLimit(1)
    }

    private func switchSource(_ source: XBSSource?) async {
        guard let source else { return }
        selectedSourceAlias = source.alias
        categories = XBSEngine.shared.bookWorldCategories(source: source)
        selectedCategory = categories.first
        await reload()
    }

    private func reload() async {
        page = 1
        books.removeAll()
        hasMore = true
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading, hasMore, let source = selectedSource else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let newBooks = try await XBSEngine.shared.bookWorld(
                source: source,
                category: selectedCategory,
                page: page
            )
            let existingURLs = Set(books.map { $0.detailUrl })
            books.append(contentsOf: newBooks.filter { !existingURLs.contains($0.detailUrl) })
            page += 1
            hasMore = !newBooks.isEmpty
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "加载失败：\(error.localizedDescription)"
            hasMore = false
        }
    }
}

// MARK: - 书单详情（书单内书籍网格）

struct XBSShudanDetailView: View {
    let shudan: XBSEngine.XBSShudan
    @State private var books: [XBSBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(shudan.title)
                    .font(.headline)
                if let desc = shudan.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(books, id: \.detailUrl) { book in

                        NavigationLink {
                            XBSBookDetailView(initialBook: book)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                BookCoverView(url: book.cover)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(3 / 4, contentMode: .fill)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                Text(book.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(shudan.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let source = XBSSourceStore.shared.source(alias: shudan.sourceAlias) else {
            errorMessage = "站点已失效"
            isLoading = false
            return
        }
        do {
            books = try await XBSEngine.shared.shudanBooks(source: source, url: shudan.detailUrl)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
