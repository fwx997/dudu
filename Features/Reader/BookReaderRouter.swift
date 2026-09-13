//
//  BookReaderRouter.swift
//  Legado-iOS
//
//  按书籍来源类型路由到对应阅读器：文本 / 漫画 / 听书
//

import SwiftUI

struct BookReaderRouter: View {
    let book: Book

    enum ReaderKind {
        case text
        case image
        case audio
    }

    var body: some View {
        switch Self.readerKind(for: book) {
        case .text:
            ReaderView(book: book)
        case .image:
            MangaReaderView(book: book)
        case .audio:
            AudioPlayerView(book: book)
        }
    }

    /// 判定阅读器类型：香色闺阁站点按 sourceType，Legado 书源按 bookSourceType
    static func readerKind(for book: Book) -> ReaderKind {
        if book.origin.hasPrefix("xbs://") {
            let alias = String(book.origin.dropFirst("xbs://".count))
            switch XBSSourceStore.shared.source(alias: alias)?.sourceType {
            case "image": return .image
            case "audio": return .audio
            default: return .text
            }
        }
        switch book.source?.bookSourceType ?? 0 {
        case 1: return .image
        case 2: return .audio
        default: return .text
        }
    }
}
