//
//  VideoReadView.swift
//  Legado-iOS
//
//  视频源阅读页（对齐 VideoReadVC）：章节列表 + AVPlayer 播放
//

import SwiftUI
import AVKit
import CoreData

struct VideoReadView: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book

    @State private var chapters: [(title: String, url: String)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playingURL: URL?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(chapters, id: \.url) { chapter in
                    Button {
                        Task {
                            if book.origin.hasPrefix("xbs://") {
                                let alias = String(book.origin.dropFirst("xbs://".count))
                                if let source = XBSSourceStore.shared.source(alias: alias),
                                   let media = try? await XBSEngine.shared.chapterAudioURL(source: source, url: chapter.url) {
                                    playingURL = media
                                }
                            } else if let u = URL(string: chapter.url) {
                                playingURL = u
                            }
                        }

                    } label: {
                        Label(chapter.title, systemImage: "play.circle")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: Binding(
            get: { playingURL.map { PlayItem(url: $0) } },
            set: { playingURL = $0?.url }
        )) { item in
            VideoScreen(url: item.url)
        }
    }

    struct PlayItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private func load() async {
        guard book.origin.hasPrefix("xbs://") else {
            errorMessage = "仅支持香色闺阁视频站点"
            isLoading = false
            return
        }
        let alias = String(book.origin.dropFirst("xbs://".count))
        guard let source = XBSSourceStore.shared.source(alias: alias) else {
            errorMessage = "站点已失效"
            isLoading = false
            return
        }
        do {
            let list = try await XBSEngine.shared.chapterList(
                source: source,
                url: book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl
            )
            chapters = list.map { (title: $0.title, url: $0.url) }

            // 选中章节的正文规则提取视频链接
            if chapters.isEmpty {
                errorMessage = "无剧集"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// 单集播放页：从章节内容规则提取视频地址后播放
struct VideoScreen: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var statusText = "正在解析视频..."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView(statusText)
                    .foregroundColor(.white)
            }
        }
        .task {
            // 直接把传入 url 当媒体地址播放（多数视频源章节 URL 即媒体流）
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
