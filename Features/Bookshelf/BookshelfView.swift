//
//  BookshelfView.swift
//  Legado-iOS
//
//  书架主界面（对齐香色闺阁真版首页截图）
//  顶部一行：[文件夹] 书架|发现分段控件 [搜索] [＋]，无底部TabBar、无大标题
//  默认列表模式：封面/类型图标 + 书名 + 源名 · 最新章节
//

import SwiftUI
import CoreData

struct BookshelfView: View {
    @ObservedObject private var tabState = MainTabState.shared
    @StateObject private var viewModel = BookshelfViewModel()
    @StateObject private var shelfStore = ShelfStore.shared
    @StateObject private var localBookViewModel = LocalBookViewModel()
    @State private var showingSourceManage = false
    @State private var showingXBSManage = false
    @State private var showingAddBook = false
    @State private var showingSearch = false
    @State private var showingShudan = false
    @State private var showingLeftDrawer = false
    @State private var showingRightDrawer = false
    @State private var isEditing = false
    @State private var selectedBookIds: Set<UUID> = []
    @State private var showingMoveSheet = false
    @State private var showingFolderMenu = false
    @State private var showingLocalBooks = false
    @State private var showingSettings = false
    @State private var sourceAction: XBSSourceManageView.InitialAction = .none
    @State private var selectedBook: Book?
    @State private var showingReader = false
    @State private var showingBookDetails = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                ZStack {
                    mainContent
                        .opacity(tabState.tab == 0 ? 1 : 0)
                        .allowsHitTesting(tabState.tab == 0)
                        .accessibilityHidden(tabState.tab != 0)
                    DiscoverHomeView()
                        .opacity(tabState.tab == 1 ? 1 : 0)
                        .allowsHitTesting(tabState.tab == 1)
                        .accessibilityHidden(tabState.tab != 1)
                }
            }

            // 左抽屉：书架分组选择（对齐 LeftViewController.selectedBookShelfGroup:）
            DrawerOverlay(side: .left, isPresented: $showingLeftDrawer) {
                ShelfListDrawer(store: shelfStore) {
                    showingLeftDrawer = false
                    Task { await viewModel.loadBooks() }
                }
            }

            // 右抽屉：功能菜单
            DrawerOverlay(side: .right, isPresented: $showingRightDrawer) {
                ShelfSideMenu(
                    onSites: { showingRightDrawer = false; showingXBSManage = true },
                    onLegadoSources: { showingRightDrawer = false; showingSourceManage = true },
                    onImportLocal: { showingRightDrawer = false; showingAddBook = true },
                    onOpenFile: {
                        showingRightDrawer = false
                        openTextFile()
                    },
                    onSort: { sort in
                        showingRightDrawer = false
                        viewModel.sortBy = sort
                    },
                    currentSort: viewModel.sortBy,
                    onViewMode: {
                        showingRightDrawer = false
                        viewModel.viewMode = viewModel.viewMode == .grid ? .list : .grid
                    },
                    currentViewMode: viewModel.viewMode
                )
                .safeAreaInset(edge: .bottom) { drawerActions }
            }
        }
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
        .navigationDestination(isPresented: $showingReader) {
            if let selectedBook { BookReaderRouter(book: selectedBook) }
        }
        .sheet(isPresented: $showingBookDetails) {
            NavigationStack {
                if let selectedBook { BookDetailView(book: selectedBook) }
            }
        }
        .onChange(of: viewModel.sortBy) { _ in
            Task { await viewModel.loadBooks() }
        }
        .onChange(of: tabState.tab) { _ in
            isEditing = false
            selectedBookIds.removeAll()
        }
    }

    // MARK: - 顶栏（真版：文件夹 | 书架/发现分段 | 搜索 ＋）

    @ViewBuilder
    private var headerBar: some View {
        if isEditing {
            HStack(spacing: 12) {
                Button {
                    isEditing = false
                    selectedBookIds.removeAll()
                } label: {
                    Text("取消")
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Text("已选 \(selectedBookIds.count) 本")
                    .fontWeight(.semibold)
                Spacer()
                // 黄色减号：移回默认书架；绿色：移到其他书架；红色：删除
                Button {
                    let books = viewModel.books.filter { selectedBookIds.contains($0.bookId) && $0.group != 0 }
                    viewModel.moveBooks(books, to: 0)
                    selectedBookIds.removeAll()
                    isEditing = false
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
                .disabled(!viewModel.books.contains { selectedBookIds.contains($0.bookId) && $0.group != 0 })
                Button {
                    guard !selectedBookIds.isEmpty else { return }
                    showingMoveSheet = true
                } label: {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .disabled(selectedBookIds.isEmpty)
                Button(role: .destructive) {
                    let books = viewModel.books.filter { selectedBookIds.contains($0.bookId) }
                    viewModel.deleteBooks(books)
                    selectedBookIds.removeAll()
                    isEditing = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .disabled(selectedBookIds.isEmpty)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
        } else {
            XSGBTopTabs(
                onFolder: { showingLeftDrawer = true },
                onSearch: { showingSearch = true },
                onAdd: { showingFolderMenu = true }
            )
        }
    }

    // MARK: - 主内容

    private var mainContent: some View {
        Group {
            if viewModel.books.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "暂无书籍",
                    subtitle: "点右上角 ＋ 导入站点，或打开本地书籍",
                    imageName: "book.closed"
                )
            } else {
                bookshelfContent
            }
        }
        .confirmationDialog("添加", isPresented: $showingFolderMenu, titleVisibility: .visible) {
            Button("站点管理") { openSources() }
            Button("网络导入") { openSources(.network) }
            Button("剪贴板导入") { openSources(.clipboard) }
            Button("本地文件导入") { openSources(.file) }
            Button("新建站点") { openSources(.newSource) }
            Button("本地书籍") { showingLocalBooks = true }
            Button("打开文本 / EPUB") { openTextFile() }
            Button("书单") { showingShudan = true }
            Button("书架管理") { showingLeftDrawer = true }
            Button("排序与显示") { showingRightDrawer = true }
            Button("配置") { showingSettings = true }
            Button("进入编辑模式") {
                isEditing = true
                selectedBookIds.removeAll()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("移动到书架", isPresented: $showingMoveSheet, titleVisibility: .visible) {
            ForEach(shelfStore.shelves) { shelf in
                Button(shelf.name) {
                    let books = viewModel.books.filter { selectedBookIds.contains($0.bookId) }
                    viewModel.moveBooks(books, to: shelf.id)
                    selectedBookIds.removeAll()
                    isEditing = false
                }
            }
        }
        .sheet(isPresented: $showingSourceManage) {
            NavigationStack { SourceManageView() }
        }
        .sheet(isPresented: $showingXBSManage) {
            NavigationStack { XBSSourceManageView(initialAction: sourceAction, canDismiss: true) }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingAddBook) {
            AddBookView { url, completion in
                Task {
                    do {
                        try await localBookViewModel.importBook(url: url)
                        await viewModel.forceReload()
                    } catch {
                        await MainActor.run {
                            localBookViewModel.errorMessage = "导入失败：\(error.localizedDescription)"
                        }
                    }
                    completion()
                }
            }
        }
        .sheet(isPresented: $showingSearch, onDismiss: { Task { await viewModel.loadBooks() } }) {
            NavigationStack { SearchResultView() }
        }
        .sheet(isPresented: $showingLocalBooks) {
            NavigationStack { LocalBooksView() }
        }
        .sheet(isPresented: $showingShudan) {
            NavigationStack { DiscoveryView(initialMode: .shudan) }
        }
        .alert("导入成功", isPresented: Binding(
            get: { localBookViewModel.successMessage != nil },
            set: { if !$0 { localBookViewModel.successMessage = nil } }
        )) {
            Button("确定", role: .cancel) { localBookViewModel.successMessage = nil }
        } message: {
            Text(localBookViewModel.successMessage ?? "")
        }
        .alert("导入失败", isPresented: Binding(
            get: { localBookViewModel.errorMessage != nil },
            set: { if !$0 { localBookViewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { localBookViewModel.errorMessage = nil }
        } message: {
            Text(localBookViewModel.errorMessage ?? "未知错误")
        }
        .task {
            shelfStore.refresh()
            viewModel.groupFilter = Int32(truncatingIfNeeded: shelfStore.currentShelfId)
            await viewModel.loadBooks()
            if AppSettings.shared.checkUpdateOnOpen {
                await viewModel.checkUpdates()
            }
        }
        .onChange(of: shelfStore.currentShelfId) { newValue in
            viewModel.groupFilter = Int32(truncatingIfNeeded: newValue)
            Task { await viewModel.loadBooks() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importLocalBookNotification)) { notification in
            guard let url = notification.object as? URL else { return }
            Task { await importBook(url) }
        }
        .refreshable {
            await viewModel.loadBooks()
            await viewModel.checkUpdates()
        }
        .overlay(alignment: .top) {
            if viewModel.isCheckingUpdates {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在检查更新...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(.systemBackground)).shadow(color: .black.opacity(0.1), radius: 4))
                .padding(.top, 4)
            }
        }
    }

    private var drawerActions: some View {
        HStack(spacing: 24) {
            Button("配置") { showingRightDrawer = false; showingSettings = true }
            Button("站点") { showingRightDrawer = false; openSources() }
        }
        .font(.subheadline)
        .padding()
    }

    private func openSources(_ action: XBSSourceManageView.InitialAction = .none) {
        sourceAction = action
        showingXBSManage = true
    }

    private func importBook(_ url: URL) async {
        do {
            try await localBookViewModel.importBook(url: url)
            await viewModel.forceReload()
        } catch {
            localBookViewModel.errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func openTextFile() {
        DocumentPickerHelper.shared.present(contentTypes: [.data]) { urls in
            guard let url = urls.first else { return }
            let ext = url.pathExtension.lowercased()
            guard ["txt", "epub"].contains(ext) else {
                localBookViewModel.errorMessage = "仅支持 txt / epub 文件，当前是 .\(ext)"
                return
            }
            Task { @MainActor in
                do {
                    try await localBookViewModel.importBook(url: url)
                    await viewModel.forceReload()
                } catch {
                    localBookViewModel.errorMessage = "导入失败：\(error.localizedDescription)"
                }
            }
        }
    }

    @ViewBuilder
    private var bookshelfContent: some View {
        switch viewModel.viewMode {
        case .grid:
            bookGridView
        case .list:
            bookListView
        }
    }

    private var bookGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 22) {
                ForEach(viewModel.books, id: \.bookId) { book in
                    shelfBookButton(book, grid: true)
                }
                loadMoreRow
            }
            .padding(14)
        }
        .refreshable { await viewModel.checkUpdates() }
    }

    private var bookListView: some View {
        List {
            ForEach(viewModel.books, id: \.bookId) { book in
                shelfBookButton(book, grid: false)
                    .listRowInsets(EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { viewModel.moveBookAt(from: $0, to: $1) }
            loadMoreRow.listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable { await viewModel.checkUpdates() }
    }

    @ViewBuilder
    private var loadMoreRow: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity)
        } else if viewModel.hasMore {
            Color.clear.frame(height: 1)
                .onAppear { Task { await viewModel.loadMoreBooks() } }
        }
    }

    private func shelfBookButton(_ book: Book, grid: Bool) -> some View {
        Button { selectBook(book) } label: {
            shelfBookLabel(book, grid: grid)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            isEditing = true
            selectedBookIds.insert(book.bookId)
        }
        .contextMenu { bookActions(book) }
    }

    private func shelfBookLabel(_ book: Book, grid: Bool) -> some View {
        HStack(spacing: 10) {
            if isEditing {
                Image(systemName: selectedBookIds.contains(book.bookId) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.accentColor)
            }
            if grid { BookGridItemView(book: book) }
            else { BookListItemView(book: book) }
        }
    }

    @ViewBuilder
    private func bookActions(_ book: Book) -> some View {
        Button("书籍详情") { selectedBook = book; showingBookDetails = true }
        Button("移动到书架") {
            selectedBookIds = [book.bookId]
            showingMoveSheet = true
        }
        Button("删除书籍", role: .destructive) { viewModel.removeBook(book) }
    }

    private func selectBook(_ book: Book) {
        if isEditing {
            if selectedBookIds.contains(book.bookId) { selectedBookIds.remove(book.bookId) }
            else { selectedBookIds.insert(book.bookId) }
            return
        }
        selectedBook = book
        showingReader = true
    }
}

// MARK: - 左抽屉：书架分组选择（对齐 LeftViewController.selectedBookShelfGroup:）

struct ShelfGroupDrawer: View {
    @ObservedObject var store: ShelfStore
    let onSwitched: () -> Void
    @State private var newShelfName = ""
    @State private var showingNewShelf = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("选择书架")
                    .font(.headline)
                Spacer()
                Button {
                    newShelfName = ""
                    showingNewShelf = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.bottom, 8)

            ForEach(store.shelves) { shelf in
                Button {
                    store.currentShelfId = shelf.id
                    onSwitched()
                } label: {
                    HStack {
                        Image(systemName: "books.vertical")
                            .foregroundColor(.secondary)
                        Text(shelf.name)
                            .foregroundColor(store.currentShelfId == shelf.id ? .accentColor : .primary)
                        Spacer()
                        if store.currentShelfId == shelf.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("新建书架", isPresented: $showingNewShelf) {
            TextField("书架名称", text: $newShelfName)
            Button("创建") {
                let name = newShelfName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { store.createShelf(named: name) }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - 右抽屉：功能菜单（原 ShelfSideMenu，含书架管理入口）

struct ShelfSideMenu: View {
    let onSites: () -> Void
    let onLegadoSources: () -> Void
    let onImportLocal: () -> Void
    let onOpenFile: () -> Void
    let onSort: (BookshelfViewModel.SortBy) -> Void
    let currentSort: BookshelfViewModel.SortBy
    let onViewMode: () -> Void
    let currentViewMode: BookshelfViewModel.ViewMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("功能菜单")
                .font(.headline)
                .padding(.bottom, 8)

            menuRow("站点管理", "square.grid.2x2", action: onSites)
            menuRow("书源管理", "books.vertical", action: onLegadoSources)
            menuRow("导入本地书籍", "square.and.arrow.down", action: onImportLocal)
            menuRow("打开 txt / epub 文件", "doc.text", action: onOpenFile)

            Divider().padding(.vertical, 8)

            Text("排序方式")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(BookshelfViewModel.SortBy.allCases, id: \.rawValue) { sort in
                Button {
                    onSort(sort)
                } label: {
                    HStack {
                        Text(sortName(sort))
                            .foregroundColor(currentSort == sort ? .accentColor : .primary)
                        Spacer()
                        if currentSort == sort {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.vertical, 8)

            menuRow(currentViewMode == .grid ? "切换为列表显示" : "切换为宫格显示",
                    currentViewMode == .grid ? "list.bullet" : "square.grid.2x2",
                    action: onViewMode)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func menuRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func sortName(_ sort: BookshelfViewModel.SortBy) -> String {
        switch sort {
        case .lastRead: return "最近阅读"
        case .name: return "书名"
        case .author: return "作者"
        case .update: return "更新时间"
        case .manual: return "手动排序"
        }
    }
}

// MARK: - 右抽屉：多书架管理

struct ShelfListDrawer: View {
    @ObservedObject var store: ShelfStore
    let onSwitched: () -> Void
    @State private var newShelfName = ""
    @State private var showingNewShelf = false
    @State private var renamingShelf: ShelfStore.Shelf?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("书架管理")
                    .font(.headline)
                Spacer()
                Button {
                    newShelfName = ""
                    showingNewShelf = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.bottom, 8)

            ForEach(store.shelves) { shelf in
                Button {
                    store.currentShelfId = shelf.id
                    onSwitched()
                } label: {
                    HStack {
                        Text(shelf.name)
                            .foregroundColor(store.currentShelfId == shelf.id ? .accentColor : .primary)
                        Spacer()
                        if store.currentShelfId == shelf.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                        if shelf.id != ShelfStore.defaultShelfId {
                            Menu {
                                Button {
                                    renameText = shelf.name
                                    renamingShelf = shelf
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    store.deleteShelf(id: shelf.id)
                                    onSwitched()
                                } label: {
                                    Label("删除书架（书移入默认书架）", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("新建书架", isPresented: $showingNewShelf) {
            TextField("书架名称", text: $newShelfName)
            Button("创建") {
                let name = newShelfName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { store.createShelf(named: name) }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("重命名书架", isPresented: Binding(
            get: { renamingShelf != nil },
            set: { if !$0 { renamingShelf = nil } }
        )) {
            TextField("书架名称", text: $renameText)
            Button("确定") {
                if let shelf = renamingShelf {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { store.renameShelf(id: shelf.id, to: name) }
                }
                renamingShelf = nil
            }
            Button("取消", role: .cancel) { renamingShelf = nil }
        }
    }
}

// MARK: - 抽屉容器

struct DrawerOverlay<Content: View>: View {
    enum Side { case left, right }
    let side: Side
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: side == .left ? .leading : .trailing) {
            if isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .transition(.opacity)

                content()
                    .frame(width: 285)
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .transition(side == .left ? .move(edge: .leading) : .move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isPresented)
    }
}

// MARK: - 网格项（被详情/发现页引用的共享组件）

struct BookGridItemView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverView(url: book.coverUrl)
                .frame(maxWidth: .infinity)
                .aspectRatio(3/4, contentMode: .fill)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(2)

            Text(book.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text(book.author)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)

        }
    }
}

// MARK: - 列表项（对齐真版：封面/彩色类型图标 + 书名 + 源名 + 最新章节）

struct BookListItemView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookshelfThumbView(book: book)
                .frame(width: 52, height: 70)
                .cornerRadius(5)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text(book.originName.isEmpty ? (book.isLocal ? "本地书籍" : "未知来源") : book.originName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let chapter = book.latestChapterTitle, !chapter.isEmpty {
                    Text("新 · " + chapter)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.75))
                        .lineLimit(1)
                } else if let dur = book.durChapterTitle, !dur.isEmpty {
                    Text("读至：\(dur)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 书架缩略图（真版：无封面时显示彩色圆角方块+类型图标）

struct BookshelfThumbView: View {
    let book: Book
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                typeBadge
            }
        }
        .frame(width: 52, height: 70)
        .clipped()
        .task {
            if let urlString = book.displayCoverUrl, !urlString.isEmpty {
                if let cached = await ImageCacheManager.shared.loadImage(from: urlString) {
                    imageData = cached.pngData()
                }
            }
        }
    }

    private var typeBadge: some View {
        Image("xsg-file-" + fileType)
            .resizable()
            .scaledToFit()
    }

    private var fileType: String {
        switch book.type {
        case 2: return "image"
        case 1: return "audio"
        case 3: return "video"
        default: return "text"
        }
    }
}

// MARK: - 封面视图

struct BookCoverView: View {
    let url: String?
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "books.vertical")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .task {
            if let urlString = url, !urlString.isEmpty {
                await loadImage(urlString: urlString)
            }
        }
    }

    private func loadImage(urlString: String) async {
        let cached = await ImageCacheManager.shared.loadImage(from: urlString)
        if let cached = cached {
            imageData = cached.pngData()
        }
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let imageName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.title2)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
