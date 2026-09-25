//
//  VideoReadView.swift
//  Legado-iOS
//
//  视频源阅读页（对齐 VideoReadVC）：内嵌播放器 + 倍速底栏 + 剧集列表 + 观看记录
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
    @State private var player: AVPlayer?
    @State private var currentEpisode = 0
    @State private var resolving = false
    @State private var showingRate = false

    static let rateOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    @State private var rate: Float = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部内嵌播放器（对齐 playerCon/playerVC）
            ZStack {
                Color.black
                if let player {
                    VideoPlayer(player: player)
                } else if resolving {
                    ProgressView("正在解析视频...")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)

            // 倍速底栏（对齐 bottomBar/showRateList）
            HStack {
                Button {
                    showingRate = true
                } label: {
                    Text(rate == 1.0 ? "倍速" : String(format: "%.2gx", rate))
                        .font(.subheadline)
                }
                Spacer()
                Button {
                    play(index: currentEpisode - 1)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(currentEpisode <= 0)
                Text(chapters.isEmpty ? "" : "第 \(currentEpisode + 1)/\(chapters.count) 集")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button {
                    play(index: currentEpisode + 1)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(currentEpisode >= chapters.count - 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)

            // 剧集列表（对齐 tableView）
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                    Button {
                        play(index: index)
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .lineLimit(1)
                                .foregroundColor(index == currentEpisode ? .red : .primary)
                            Spacer()
                            if index == currentEpisode {
                                Image(systemName: "waveform")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { player?.pause() }
        .confirmationDialog("播放倍速", isPresented: $showingRate, titleVisibility: .visible) {
            ForEach(Self.rateOptions, id: \.self) { r in
                Button(r == 1.0 ? "正常" : String(format: "%.2gx", r)) {
                    setRate(r)
                }
            }
        }
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
            if chapters.isEmpty {
                errorMessage = "无剧集"
            } else {
                // onOpenRecord/getReadRecord：恢复上次观看的剧集
                play(index: min(Int(book.durChapterIndex), chapters.count - 1))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func play(index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentEpisode = index
        saveRecord(index: index)
        Task { await resolveAndPlay(index: index) }
    }

    private func resolveAndPlay(index: Int) async {
        resolving = true
        defer { resolving = false }
        let chapter = chapters[index]
        let mediaURL: URL?
        if book.origin.hasPrefix("xbs://") {
            let alias = String(book.origin.dropFirst("xbs://".count))
            if let source = XBSSourceStore.shared.source(alias: alias) {
                mediaURL = try? await XBSEngine.shared.chapterAudioURL(source: source, url: chapter.url)
            } else {
                mediaURL = nil
            }
        } else {
            mediaURL = URL(string: chapter.url)
        }
        guard let mediaURL else { return }
        let newPlayer = AVPlayer(url: mediaURL)
        newPlayer.defaultRate = rate
        player = newPlayer
        newPlayer.play()
    }

    private func setRate(_ newRate: Float) {
        rate = newRate
        player?.defaultRate = newRate
        player?.rate = newRate
    }

    private func saveRecord(index: Int) {
        book.durChapterIndex = Int32(index)
        try? book.managedObjectContext?.save()
    }
}
