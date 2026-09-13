//
//  LocalBooksView.swift
//  Legado-iOS
//
//  本地书籍列表（对齐 LocalBookListVC）
//

import SwiftUI
import CoreData

struct LocalBooksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var books: [Book] = []

    var body: some View {
        Group {
            if books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无本地书籍")
                        .font(.headline)
                    Text("请从第三方App导入txt文件，例如通过浏览器下载txt后再使用嘟嘟打开")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(books, id: \.bookId) { book in
                        NavigationLink {
                            BookReaderRouter(book: book)
                        } label: {
                            BookListItemView(book: book)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("本地书籍")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func load() {
        let context = CoreDataStack.shared.viewContext
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "origin == %@", "local")
        books = (try? context.fetch(request)) ?? []
    }
}
