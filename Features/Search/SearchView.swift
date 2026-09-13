//
//  SearchView.swift
//  Legado-iOS
//
//  搜索界面
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var showSourcePicker = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏和过滤按钮
                searchBar

                if searchText.isEmpty {
                    // 空状态：显示历史和热词
                    emptyStateView
                } else if viewModel.isSearching {
                    // 搜索中
                    loadingView
                } else if viewModel.filteredResults.isEmpty {
                    // 无结果
                    emptyResultsView
                } else {
                    // 搜索结果列表
                    resultsList
                }
            }
            .navigationTitle("发现")
            .sheet(isPresented: $showFilterSheet) {
                SearchFilterSheet()
            }
            .sheet(isPresented: $showSourcePicker) {
                SearchSourcePicker(selectedSources: $viewModel.selectedSources)
            }
        }
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索书籍", text: $searchText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.searchResults = []
                        viewModel.filteredResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 搜索历史
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
                                Button {
                                    viewModel.searchWithHistory(keyword)
                                    searchText = keyword
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(keyword)
                                            .font(.subheadline)

                                        Button {
                                            viewModel.removeHistory(keyword)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(999)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 热门搜索
                if !viewModel.hotWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.hotWords, id: \.self) { word in
                                Button {
                                    viewModel.searchWithHotWord(word)
                                    searchText = word
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

    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在搜索...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空结果视图
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("未找到相关书籍")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 结果列表
    private var resultsList: some View {
        List {
            Section {
                ForEach(viewModel.filteredResults) { result in
                    SearchResultRow(result: result, viewModel: viewModel)
                }
            } header: {
                Text("共找到 \(viewModel.filteredResults.count) 本书")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 执行搜索
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        viewModel.searchText = searchText
        Task {
            await viewModel.search(keyword: searchText, sources: viewModel.selectedSources)
        }
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let result: SearchViewModel.SearchResult
    let viewModel: SearchViewModel

    @State private var isAdding = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 封面
            AsyncImage(url: URL(string: result.coverUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray5)
                    .overlay(
                        Image(systemName: "book")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 80)
            .cornerRadius(6)

            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(result.displayAuthor)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let intro = result.displayIntro {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(result.sourceName)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }

            Spacer()

            // 添加按钮
            Button {
                addToBookshelf()
            } label: {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .disabled(isAdding)
        }
        .padding(.vertical, 4)
    }

    private func addToBookshelf() {
        isAdding = true
        Task {
            do {
                _ = try await viewModel.addToBookshelf(result: result)
                isAdding = false
            } catch {
                isAdding = false
            }
        }
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - 搜索过滤设置表单
struct SearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("searchFilterType") private var filterType: SearchFilterType = .noFilter
    @AppStorage("searchSourceType") private var sourceType: SourceType = .text

    var body: some View {
        NavigationView {
            Form {
                Section("搜索结果过滤") {
                    Picker("过滤方式", selection: $filterType) {
                        Text("不过滤").tag(SearchFilterType.noFilter)
                        Text("匹配关键字").tag(SearchFilterType.matchKeyword)
                        Text("包含关键字").tag(SearchFilterType.containsKeyword)
                    }
                }

                Section("书源类型") {
                    Picker("类型", selection: $sourceType) {
                        Text("全部").tag(SourceType.all)
                        Text("文本").tag(SourceType.text)
                        Text("图片").tag(SourceType.image)
                        Text("音频").tag(SourceType.audio)
                        Text("视频").tag(SourceType.video)
                    }
                }
            }
            .navigationTitle("搜索设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 书源选择器
struct SearchSourcePicker: View {
    @Binding var selectedSources: [BookSource]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Text("书源选择功能开发中")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("选择书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
}
