//
//  BookshelfView.swift
//  Legado-iOS
//
//  书架主界面（对齐香色闺阁 BookShelfController）
//  结构：顶部导航（左菜单/书架名/搜索/分组/书单）+ 左右抽屉 + 宫格/列表
//

import SwiftUI
import CoreData

struct BookshelfView: View {
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

    var body: some View {
        ZStack {
            mainContent

            // 左抽屉：书架分组选择（对齐 LeftViewController.selectedBookShelfGroup:）
            DrawerOverlay(side: .left, isPresented: $showingLeftDrawer) {
                ShelfGroupDrawer(store: shelfStore) {
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
            }
        }
    }

    // MARK: - 主内容

    private var mainContent: some View {
        Group {
            if viewModel.books.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "书架空空如也",
                    subtitle: "点击右上角添加书籍或导入书源",
                    imageName: "books.vertical"
                )
            } else {
                bookshelfContent
            }
        }
        .navigationTitle(isEditing ? "已选 \(selectedBookIds.count) 本" : shelfStore.currentName)
        .toolbar {
            if isEditing {
                // 编辑模式工具栏（对齐 onSelectAllEvent/onMoveEvent/onDeleteEvent/onEndEditEvent）
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("全选") {
                        if selectedBookIds.count == viewModel.books.count {
                            selectedBookIds.removeAll()
                        } else {
                            selectedBookIds = Set(viewModel.books.map { $0.bookId })
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button("移动") {
                            guard !selectedBookIds.isEmpty else { return }
                            showingMoveSheet = true
                        }
                        .foregroundColor(selectedBookIds.isEmpty ? .secondary : .accentColor)

                        Button("删除", role: .destructive) {
                            let books = viewModel.books.filter { selectedBookIds.contains($0.bookId) }
                            viewModel.deleteBooks(books)
                            selectedBookIds.removeAll()
                        }
                        .foregroundColor(selectedBookIds.isEmpty ? .secondary : .red)

                        Button("完成") {
                            isEditing = false
                            selectedBookIds.removeAll()
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFolderMenu = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button(action: { showingSearch = true }) {
                            Image(systemName: "magnifyingglass")
                        }

                        // 分组/多书架（对齐真版四圆图标）
                        Button {
                            showingLeftDrawer = true
                        } label: {
                            Image(systemName: "circle.grid.2x2")
                        }

                        // 书单（对齐真版星标图标）
                        Button {
                            showingShudan = true
                        } label: {
                            Image(systemName: "star")
                        }

                        Button(action: { showingAddBook = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .confirmationDialog("文件夹", isPresented: $showingFolderMenu, titleVisibility: .visible) {
            Button("站点管理") { showingXBSManage = true }
            Button("书源管理") { showingSourceManage = true }
            Button("导入本地书籍") { showingAddBook = true }
            Button("打开 txt / epub 文件") { openTextFile() }
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
            NavigationStack { XBSSourceManageView() }
        }
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
        .sheet(isPresented: $showingSearch) {
            NavigationStack { SearchResultView() }
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
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.books, id: \.bookId) { book in
                    Group {
                        if isEditing {
                            Button {
                                if selectedBookIds.contains(book.bookId) {
                                    selectedBookIds.remove(book.bookId)
                                } else {
                                    selectedBookIds.insert(book.bookId)
                                }
                            } label: {
                                BookGridItemView(book: book)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: selectedBookIds.contains(book.bookId) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(selectedBookIds.contains(book.bookId) ? .accentColor : .white)
                                            .shadow(radius: 2)
                                            .padding(4)
                                    }
                                    .opacity(selectedBookIds.isEmpty || selectedBookIds.contains(book.bookId) ? 1 : 0.5)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: BookReaderRouter(book: book)) {
                                BookGridItemView(book: book)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(LongPressGesture().onEnded { _ in
                                isEditing = true
                                selectedBookIds.insert(book.bookId)
                            })
                        }
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if viewModel.hasMore {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreBooks()
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }

    private var bookListView: some View {
        List {
            ForEach(viewModel.books, id: \.bookId) { book in
                Group {
                    if isEditing {
                        Button {
                            if selectedBookIds.contains(book.bookId) {
                                selectedBookIds.remove(book.bookId)
                            } else {
                                selectedBookIds.insert(book.bookId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedBookIds.contains(book.bookId) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedBookIds.contains(book.bookId) ? .accentColor : .secondary)
                                BookListItemView(book: book)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: BookReaderRouter(book: book)) {
                            BookListItemView(book: book)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    viewModel.removeBook(viewModel.books[index])
                }
            }
        }
        .listStyle(.insetGrouped)
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
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            Text(book.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text(book.author)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)

            ProgressView(value: book.readProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

// MARK: - 列表项

struct BookListItemView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(url: book.coverUrl)
                .frame(width: 60, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let chapter = book.latestChapterTitle {
                    Text(chapter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack {
                    ProgressView(value: book.readProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)

                    Text("\(Int(book.readProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
