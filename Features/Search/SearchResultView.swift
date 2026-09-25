//
//  SearchResultView.swift
//  Legado-iOS
//
//  聚合搜索视图（香色闺阁风格：历史/热词、流式并发、进度展示、关键字过滤）
//

import SwiftUI
import CoreData

struct SearchResultView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingSourcePicker = false
    @State private var showingFilterSheet = false
    @State private var navigatingToBookDetail = false
    @State private var selectedBook: Book?
    @State private var selectedXBSBook: XBSBook?
    @Environment(\.dismiss) private var dismiss
    @State private var openingResultId: UUID?
    @State private var relatedWords: [String] = []

    var body: some View {
        Group {
            if viewModel.searchText.isEmpty {
                emptyStateView
            } else if viewModel.filteredResults.isEmpty {
                if viewModel.isSearching {
                    searchingView
                } else {
                    noResultView
                }
            } else {
                resultsList
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "书名 / 作者")
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: settings.searchSourceType) { _ in
            viewModel.refreshSources()
        }
        .onChange(of: settings.searchFilterType) { _ in
            viewModel.reapplyFilter()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("返回") { dismiss() } }
            ToolbarItem {
                Button(action: { showingFilterSheet = true }) {
                    Label("搜索设置", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem {
                Button(action: { showingSourcePicker = true }) {
                    Label("书源", systemImage: "square.grid.2x2")
                }
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(selectedSources: $viewModel.selectedSources, selectedXBSAliases: $viewModel.selectedXBSAliases)
        }
        .sheet(isPresented: $showingFilterSheet) {
            SearchFilterSheet()
        }
        .navigationDestination(isPresented: $navigatingToBookDetail) {
            if let selectedXBSBook {
                XBSBookDetailView(initialBook: selectedXBSBook)
            } else if let book = selectedBook {
                BookDetailView(book: book)
            } else {
                Text("未找到书籍")
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    // MARK: - 执行搜索

    private func performSearch() {
        guard !viewModel.searchText.isEmpty else { return }
        relatedWords.removeAll()
        Task {
            await viewModel.search(keyword: viewModel.searchText, sources: viewModel.selectedSources)
            // 对齐 arrRelateWord：无结果时展示站点联想词
            if viewModel.filteredResults.isEmpty {
                await loadRelatedWords(viewModel.searchText)
            }
        }
    }

    /// 相关词联想（并发询问所有启用站点）
    private func loadRelatedWords(_ keyword: String) async {
        var words: [String] = []
        await withTaskGroup(of: [String].self) { group in
            for source in XBSSourceStore.shared.enabledSources where source.action("relatedWord") != nil {
                group.addTask {
                    await XBSEngine.shared.relatedWords(source: source, keyword: keyword)
                }
            }
            for await w in group {
                words.append(contentsOf: w)
            }
        }
        var seen = Set<String>()
        relatedWords = words.filter { seen.insert($0).inserted }.prefix(12).map { $0 }
    }

    // MARK: - 空状态：搜索历史 + 热门搜索

    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.headline)

                            Spacer()

                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.searchHistory, id: \.self) { keyword in
                                HStack(spacing: 4) {
                                    Button {
                                        viewModel.searchWithHistory(keyword)
                                    } label: {
                                        Text(keyword)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        viewModel.removeHistory(keyword)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(999)
                            }
                        }
                    }
                }

                if !viewModel.hotWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.hotWords, id: \.self) { word in
                                Button {
                                    viewModel.searchWithHotWord(word)
                                } label: {
                                    Text(word)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 搜索中（显示源进度）

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)

            if viewModel.totalSourceCount > 0 {
                Text("正在搜索 \(viewModel.searchedSourceCount)/\(viewModel.totalSourceCount) 个书源")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: Double(viewModel.searchedSourceCount),
                             total: Double(max(1, viewModel.totalSourceCount)))
                    .frame(width: 220)
            } else {
                Text("正在搜索...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 无结果

    private var noResultView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("未找到相关书籍")
                    .foregroundColor(.secondary)
                Text("试试更换关键词或切换书源类型")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))

                // 相关词联想（对齐 arrRelateWord）
                if !relatedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("相关词")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        FlowLayout(spacing: 8) {
                            ForEach(relatedWords, id: \.self) { word in
                                Button {
                                    viewModel.searchWithHistory(word)
                                } label: {
                                    Text(word)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    // MARK: - 结果列表（搜索中也持续流式刷新）

    private var resultsList: some View {
        List {
            Section {
                ForEach(viewModel.filteredResults) { result in
                    Button {
                        if let alias = result.xbsAlias {
                            selectedBook = nil
                            selectedXBSBook = XBSBook(name: result.name, author: result.author,
                                cover: result.coverUrl, desc: result.intro, cat: nil, status: nil,
                                lastChapterTitle: nil, updateTime: nil, detailUrl: result.bookUrl,
                                sourceAlias: alias, sourceName: result.sourceName)
                            navigatingToBookDetail = true
                            return
                        }
                        guard openingResultId == nil else { return }
                        selectedXBSBook = nil
                        openingResultId = result.id
                        Task {
                            defer { openingResultId = nil }
                            do {
                                selectedBook = try await viewModel.addToBookshelf(result: result)
                                navigatingToBookDetail = true
                            } catch {
                                viewModel.errorMessage = "加入书架失败：\(error.localizedDescription)"
                            }
                        }
                    } label: {
                        SearchResultItemView(result: result)
                    }
                    .buttonStyle(.plain)
                    .disabled(openingResultId == result.id)
                }
            } header: {
                if viewModel.isSearching {
                    Text("已搜 \(viewModel.searchedSourceCount)/\(viewModel.totalSourceCount) 个书源 · 找到 \(viewModel.filteredResults.count) 本")
                } else {
                    Text("共找到 \(viewModel.filteredResults.count) 本书")
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 搜索结果行

struct SearchResultItemView: View {
    let result: SearchViewModel.SearchResult

    var body: some View {
        HStack(spacing: 10) {
            // 封面
            BookCoverView(url: result.coverUrl)
                .frame(width: 54, height: 72)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 4) {
                // 书名（繁简转换后展示）
                Text(result.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                // 作者
                Text(result.displayAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 书源
                Text(result.sourceName)
                    .font(.caption2)
                    .foregroundColor(.blue)

                // 简介
                if let intro = result.displayIntro, !intro.isEmpty {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

// MARK: - 书源选择器

struct SourcePickerView: View {
    @Binding var selectedSources: [BookSource]
    @Binding var selectedXBSAliases: Set<String>?
    @ObservedObject private var xbsStore = XBSSourceStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var sources: [BookSource] = []

    var body: some View {
        NavigationView {
            List {
                Section("站点") {
                    Button("全部启用站点") { selectedXBSAliases = nil }
                    ForEach(xbsStore.enabledSources) { source in xbsSourceRow(source) }
                }
                ForEach(sources, id: \.sourceId) { source in
                    HStack {
                        Text(source.displayName)

                        Spacer()

                        if selectedSources.contains(where: { $0.sourceId == source.sourceId }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSource(source)
                    }
                }
            }
            .navigationTitle("选择书源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSources()
            }
        }
    }

    private func xbsSourceRow(_ source: XBSSource) -> some View {
        Button { toggleXBS(source) } label: {
            HStack {
                Text(source.sourceName).foregroundColor(.primary)
                Spacer()
                if selectedXBSAliases == nil || selectedXBSAliases!.contains(source.alias) {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func toggleXBS(_ source: XBSSource) {
        var aliases = selectedXBSAliases ?? Set(xbsStore.enabledSources.map(\.alias))
        if aliases.contains(source.alias) { aliases.remove(source.alias) }
        else { aliases.insert(source.alias) }
        selectedXBSAliases = aliases
    }

    private func loadSources() async {
        do {
            sources = try CoreDataStack.shared.viewContext.fetch(BookSource.fetchRequest())
        } catch {
            print("加载书源失败：\(error)")
        }
    }

    private func toggleSource(_ source: BookSource) {
        if let index = selectedSources.firstIndex(where: { $0.sourceId == source.sourceId }) {
            selectedSources.remove(at: index)
        } else {
            selectedSources.append(source)
        }
    }
}

#Preview {
    NavigationStack {
        SearchResultView()
    }
}
