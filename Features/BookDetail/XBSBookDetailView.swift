//
//  XBSBookDetailView.swift
//  Legado-iOS
//
//  香色闺阁站点书籍详情页：详情补全 + 加入书架 + 开始阅读
//

import SwiftUI
import CoreData

struct XBSBookDetailView: View {
    @State private var book: XBSBook
    @State private var isLoadingDetail = true
    @State private var shelfBook: Book?
    @State private var navigatingToReader = false
    @State private var actionMessage: String?
    @State private var showingAddConfirm = false
    @State private var showingReader = false

    init(initialBook: XBSBook) {
        _book = State(initialValue: initialBook)
        _shelfBook = State(initialValue: Self.findOnShelf(initialBook))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部
                HStack(alignment: .top, spacing: 16) {
                    BookCoverView(url: book.cover)
                        .frame(width: 105, height: 140)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.name)
                            .font(.headline)
                            .lineLimit(3)

                        Text(book.author.isEmpty ? "未知作者" : book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let status = book.status, !status.isEmpty {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        if let cat = book.cat, !cat.isEmpty {
                            Text(cat)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("来源：\(book.sourceName)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)

                        if let latest = book.lastChapterTitle, !latest.isEmpty {
                            Text("最新：\(latest)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }

                // 操作按钮
                HStack(spacing: 12) {
                    Button {
                        if shelfBook != nil { addToShelf() } else { showingAddConfirm = true }
                    } label: {
                        Text(shelfBook != nil ? "已在书架" : "加入书架")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(shelfBook != nil ? Color(.systemGray5) : Color.accentColor.opacity(0.15))
                            .foregroundColor(shelfBook != nil ? .secondary : .accentColor)
                            .cornerRadius(8)
                    }
                    .disabled(shelfBook != nil)
                    .buttonStyle(.plain)

                    Button {
                        ensureOnShelf()
                        showingReader = true
                    } label: {
                        Text(shelfBook != nil ? "继续阅读" : "开始阅读")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // 简介
                if let desc = book.desc, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("简介")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }

                if isLoadingDetail {
                    HStack {
                        Spacer()
                        ProgressView("正在获取书籍详情...")
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // 对齐 BookDetailController.updateDetail
                    Button {
                        Task { await refreshDetail(force: true) }
                    } label: {
                        Label("刷新详情", systemImage: "arrow.clockwise")
                    }
                    // 对齐 BookDetailController.updateCatalog
                    Button {
                        Task { await refreshToc() }
                    } label: {
                        Label("刷新目录", systemImage: "list.bullet")
                    }
                    .disabled(shelfBook == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await refreshDetail()
        }
        .navigationDestination(isPresented: $showingReader) {
            if let shelfBook {
                BookReaderRouter(book: shelfBook)
            }
        }
        .confirmationDialog("是否将本书加入书架", isPresented: $showingAddConfirm, titleVisibility: .visible) {
            Button("加入书架") { addToShelf() }
            Button("不加入", role: .cancel) {}
        } message: {
            Text("可在设置中选择不提示")
        }
        .alert("提示", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("确定", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
    }

    // MARK: - 数据

    /// 用 bookDetail 配置补全详情
    private func refreshDetail(force: Bool = false) async {
        if force { isLoadingDetail = true }
        defer { if force { isLoadingDetail = false } }
        let alias = book.sourceAlias
        guard let source = XBSSourceStore.shared.source(alias: alias) else { return }
        guard source.action("bookDetail") != nil else { return }
        if let detail = try? await XBSEngine.shared.bookDetail(source: source, url: book.detailUrl) {
            if !detail.name.isEmpty { book.name = detail.name }
            if !detail.author.isEmpty { book.author = detail.author }
            if detail.cover != nil { book.cover = detail.cover }
            if let desc = detail.desc, !desc.isEmpty { book.desc = desc }
            if let latest = detail.lastChapterTitle, !latest.isEmpty { book.lastChapterTitle = latest }
            if let status = detail.status, !status.isEmpty { book.status = status }
            if force { actionMessage = "详情已更新" }
        }
    }

    /// 刷新目录：清掉旧章节记录后按站点规则重建（对齐 updateCatalog）
    private func refreshToc() async {
        guard let shelfBook else { return }
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        let context = CoreDataStack.shared.viewContext
        guard let source = XBSSourceStore.shared.source(alias: book.sourceAlias) else { return }
        do {
            let request = BookChapter.fetchRequest(byBookId: shelfBook.bookId)
            for old in try context.fetch(request) {
                context.delete(old)
            }
            let chapters = try await XBSEngine.shared.chapterList(source: source, url: shelfBook.tocUrl.isEmpty ? shelfBook.bookUrl : shelfBook.tocUrl)
            for (index, c) in chapters.enumerated() {
                let chapter = BookChapter.create(in: context, bookId: shelfBook.bookId, url: c.url, index: Int32(index), title: c.title)
                chapter.book = shelfBook
                chapter.sourceId = shelfBook.origin
            }
            shelfBook.totalChapterNum = Int32(chapters.count)
            try CoreDataStack.shared.save()
            actionMessage = "目录已更新，共 \(chapters.count) 章"
        } catch {
            actionMessage = "目录刷新失败：\(error.localizedDescription)"
        }
    }

    private static func findOnShelf(_ xbsBook: XBSBook) -> Book? {
        let context = CoreDataStack.shared.viewContext
        let request = Book.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "bookUrl == %@ AND origin == %@",
                                        xbsBook.detailUrl, "xbs://" + xbsBook.sourceAlias)
        return try? context.fetch(request).first
    }

    private func addToShelf() {
        do {
            let saved = try Self.addToShelf(book)
            shelfBook = saved
            actionMessage = "已加入书架"
        } catch {
            actionMessage = "加入书架失败：\(error.localizedDescription)"
        }
    }

    private func ensureOnShelf() {
        if shelfBook == nil {
            addToShelf()
        }
    }

    /// XBS 书籍入架（搜索页与详情页共用）
    static func addToShelf(_ xbsBook: XBSBook) throws -> Book {
        let context = CoreDataStack.shared.viewContext
        if let existing = findOnShelf(xbsBook) {
            return existing
        }

        let newBook = Book.create(in: context)
        newBook.name = xbsBook.name
        newBook.author = xbsBook.author
        newBook.coverUrl = xbsBook.cover
        newBook.intro = xbsBook.desc ?? ""
        newBook.bookUrl = xbsBook.detailUrl
        newBook.tocUrl = ""
        newBook.origin = "xbs://" + xbsBook.sourceAlias
        newBook.originName = xbsBook.sourceName
        if let latest = xbsBook.lastChapterTitle {
            newBook.latestChapterTitle = latest
        }

        try CoreDataStack.shared.save()
        return newBook
    }
}
