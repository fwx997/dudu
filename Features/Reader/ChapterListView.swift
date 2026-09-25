//
//  ChapterListView.swift
//  Legado-iOS
//
//  目录页（对齐真版）
//  顶栏：返回 | 目录|书签分段控件 | 到底；章节编号列表，当前章红色
//

import SwiftUI
import CoreData

struct ChapterListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let book: Book
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var reversed = false
    @State private var mode = 0 // 0=目录 1=书签
    @State private var bookmarks: [Bookmark] = []
    @State private var jumpToBottomTrigger = 0

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
            VStack(spacing: 0) {
                // 搜索行 + 正/倒序
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("搜索章节", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(.systemGray6))
                    .cornerRadius(9)

                    Button {
                        reversed.toggle()
                    } label: {
                        Image(systemName: reversed ? "arrow.up" : "arrow.down")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if mode == 0 {
                    chapterList
                } else {
                    bookmarkList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .principal) {
                    // 真版：目录|书签 分段控件
                    HStack(spacing: 0) {
                        segTab("目录", 0)
                        segTab("书签", 1)
                    }
                    .background(Capsule().fill(Color(.systemGray5).opacity(0.7)))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if mode == 0 {
                        Button {
                            jumpToBottomTrigger += 1
                        } label: {
                            Text("到底部").font(.subheadline)
                        }
                    }
                }
            }
            .onAppear { loadBookmarks() }
        }
    }

    private func segTab(_ title: String, _ tag: Int) -> some View {
        let selected = mode == tag
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) { mode = tag }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(selected ? Color(.systemGray4).opacity(0.9) : Color.clear)
                )
                .foregroundColor(selected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: 章节列表（真版：编号. 标题，当前章红色）

    private var chapterList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(displayChapters, id: \.element.chapterId) { index, chapter in
                    Button {
                        viewModel.jumpToChapter(index)
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .foregroundColor(index == viewModel.currentChapterIndex ? .accentColor : .secondary)
                                .frame(minWidth: 34, alignment: .trailing)

                            Text(chapter.title)
                                .font(.subheadline)
                                .foregroundColor(index == viewModel.currentChapterIndex ? .accentColor : .primary)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if chapter.isCached {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, XSGMetrics.chapterRowHeight)
            .onChange(of: jumpToBottomTrigger) { _ in
                if let last = displayChapters.last {
                    proxy.scrollTo(last.element.chapterId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: 书签列表

    private var bookmarkList: some View {
        Group {
            if bookmarks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无书签")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(bookmarks, id: \.bookmarkId) { bookmark in
                        Button {
                            if Int(bookmark.chapterIndex) < viewModel.chapters.count {
                                viewModel.jumpToChapter(Int(bookmark.chapterIndex))
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.content)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text("第\(bookmark.chapterIndex + 1)章 · \(bookmark.createDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            let target = bookmarks[index]
                            CoreDataStack.shared.viewContext.delete(target)
                            try? CoreDataStack.shared.viewContext.save()
                            loadBookmarks()
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 48)
            }
        }
    }

    private func loadBookmarks() {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createDate", ascending: false)]
        bookmarks = (try? CoreDataStack.shared.viewContext.fetch(request)) ?? []
    }
}
