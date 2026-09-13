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
        case video
    }

    var body: some View {
        switch Self.readerKind(for: book) {
        case .text:
            ReaderView(book: book)
        case .image:
            MangaReaderView(book: book)
        case .audio:
            AudioPlayerView(book: book)
        case .video:
            VideoReadView(book: book)
        }
    }

    /// 判定阅读器类型：香色闺阁站点按 sourceType，Legado 书源按 bookSourceType
    static func readerKind(for book: Book) -> ReaderKind {
        if book.origin.hasPrefix("xbs://") {
            let alias = String(book.origin.dropFirst("xbs://".count))
            switch XBSSourceStore.shared.source(alias: alias)?.sourceType {
            case "image": return .image
            case "audio": return .audio
            case "video": return .video
            default: return .text
            }
        }
        switch book.source?.bookSourceType ?? 0 {
        case 1: return .image
        case 2: return .audio
        case 3: return .video
        default: return .text
        }
    }
}

extension Color {
    /// "#1a1a2e" / "1a1a2e" 形式的十六进制颜色
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(red: Double((rgb >> 16) & 0xFF) / 255.0,
                  green: Double((rgb >> 8) & 0xFF) / 255.0,
                  blue: Double(rgb & 0xFF) / 255.0)
    }
}

// MARK: - 数组安全下标（全局唯一实现）

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
