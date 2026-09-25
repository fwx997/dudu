//
//  ReaderView.swift
//  Legado-iOS
//
//  阅读器主界面
//

import SwiftUI
import CoreData

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReaderViewModel()
    @StateObject private var ttsManager = TTSManager()
    @StateObject private var autoPageTurnManager = AutoPageTurnManager()
    @StateObject private var readingEnhancementManager = ReadingEnhancementManager()
    
    @State private var showingSettings = false
    @State private var showingChapterList = false
    @State private var showingTTSControls = false
    @State private var showingAutoPageTurn = false
    @State private var showingChangeSource = false
    @State private var showingBookmarks = false
    @State private var showUI = true
    @State private var showingBookDetail = false
    @State private var showingSearchContent = false
    @State private var showingContentEdit = false
    @State private var showingPageTutorial = false
    @State private var showingCacheRange = false
    @AppStorage("r_statusBarStatus") private var statusBarStatus = 0
    @AppStorage("tr_autoDarkModel") private var autoDarkModel = false
    @Environment(\.openURL) private var openURL
    
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                XSGPaperBackground(viewModel: viewModel)
                    .ignoresSafeArea()
                
                // 内容区域
                PagedReaderView(viewModel: viewModel) {
                    autoPageTurnManager.handleTouch()
                    withAnimation { showUI.toggle() }
                }
                
                // MARK: 顶部工具栏（真版：返回+章节名+听书/目录/更多）
                VStack {
                    HStack(spacing: 4) {
                        Button(action: {
                            viewModel.saveProgress()
                            dismiss()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "chevron.left")
                                Text(book.name)
                                    .lineLimit(1)
                            }
                            .font(.subheadline)
                            .frame(height: 44)
                            .padding(.horizontal, 6)
                        }

                        Spacer()

                        Button(action: { showingTTSControls = true }) {
                            XSGReaderIcon(name: "yuyin", size: 22)
                                .frame(width: 40, height: 44)
                        }
                        Button(action: { showingChapterList = true }) {
                            XSGReaderIcon(name: "mulu", size: 22)
                                .frame(width: 40, height: 44)
                        }
                        Menu {
                            Button {
                                showingBookDetail = true
                            } label: {
                                Label("书籍详情", systemImage: "info.circle")
                            }
                            Button {
                                Task { await viewModel.reloadCurrentChapter() }
                            } label: {
                                Label("刷新内容", systemImage: "arrow.clockwise")
                            }
                            Button {
                                showingSearchContent = true
                            } label: {
                                Label("搜索内容", systemImage: "magnifyingglass")
                            }
                            Button {
                                showingContentEdit = true
                            } label: {
                                Label("过滤内容", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            Button {
                                showingPageTutorial = true
                            } label: {
                                Label("翻页区域", systemImage: "hand.tap")
                            }
                            Button {
                                showingAutoPageTurn = true
                            } label: {
                                Label("自动翻页", systemImage: "timer")
                            }
                            Button {
                                showingBookmarks = true
                            } label: {
                                Label("书签", systemImage: "bookmark")
                            }
                            Button {
                                if let url = URL(string: "https://www.baidu.com/s?word=\(book.name)") {
                                    openURL(url)
                                }
                            } label: {
                                Label("百度搜索", systemImage: "safari")
                            }
                        } label: {
                            XSGReaderIcon(name: "more", size: 22)
                                .frame(width: 40, height: 44)
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: showUI)

                    Spacer()
                }

                // MARK: 右缘浮动圆形菜单钮（真版：UI隐藏时可点它呼出菜单）
                if !showUI {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation { showUI = true }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.35))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "ellipsis")
                                        .font(.body)
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 10)
                        }
                        .padding(.top, 120)
                        Spacer()
                    }
                    .transition(.opacity)
                }

                // MARK: 底部面板（真版深色：上一章/滑杆/下一章 + 目录 缓存 设置 换源）
                VStack {
                    Spacer()

                    if showUI {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Button {
                                    Task { await viewModel.prevChapter() }
                                } label: {
                                    Text("上一章")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .disabled(viewModel.currentChapterIndex <= 0)
                                .opacity(viewModel.currentChapterIndex <= 0 ? 0.4 : 1)

                                Slider(value: Binding(
                                    get: { Double(viewModel.currentChapterIndex) },
                                    set: { viewModel.jumpToChapter(Int($0)) }
                                ), in: 0...Double(max(1, viewModel.totalChapters - 1)), step: 1)
                                .tint(XSGTheme.brandRed)

                                Button {
                                    Task { await viewModel.nextChapter() }
                                } label: {
                                    Text("下一章")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .disabled(viewModel.currentChapterIndex >= viewModel.totalChapters - 1)
                                .opacity(viewModel.currentChapterIndex >= viewModel.totalChapters - 1 ? 0.4 : 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 6)

                            HStack(spacing: 0) {
                                ReaderBottomPanelButton(image: "mulu", title: "目录") { showingChapterList = true }
                                ReaderBottomPanelButton(image: "yudu", title: "缓存") { showingCacheRange = true }
                                ReaderBottomPanelButton(image: "zihao", title: "设置") { showingSettings = true }
                                ReaderBottomPanelButton(image: "shuaxin", title: "换源") { showingChangeSource = true }
                            }
                            .padding(.vertical, 10)
                        }
                        .background(Color(red: 0.13, green: 0.13, blue: 0.14).opacity(0.96))
                        .opacity(showUI ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.25), value: showUI)
                    }
                }
                
                // 设置面板
                if showingSettings {
                    ReaderSettingsView(viewModel: viewModel, isPresented: $showingSettings, onOpenChapterList: {
                        showingChapterList = true
                    })
                    .transition(.move(edge: .bottom))
                }
                
                if showingTTSControls {
                    TTSControlsView(ttsManager: ttsManager, viewModel: viewModel, isPresented: $showingTTSControls)
                        .transition(.opacity)
                }
                
                if showingAutoPageTurn {
                    AutoPageTurnControlsView(manager: autoPageTurnManager, isPresented: $showingAutoPageTurn)
                        .transition(.opacity)
                }
                
                AutoPageTurnOverlay(manager: autoPageTurnManager)
                
                // 加载指示器
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // 全本缓存进度
                if let cacheText = viewModel.cacheProgressText {
                    VStack {
                        Text(cacheText)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                // 错误提示
                if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .onAppear {
                viewModel.loadBook(book)
                autoPageTurnManager.onTurnPage = { viewModel.turnToNextPage() }
                autoPageTurnManager.onChapterComplete = {
                    Task { @MainActor in
                        await viewModel.nextChapter()
                    }
                }
                readingEnhancementManager.onNightModeChanged = { isNight in
                    guard AppSettings.shared.autoNightMode || autoDarkModel else { return }
                    viewModel.applyTheme(isNight ? .dark : .light)
                }
                readingEnhancementManager.startReadingSession()
                UIApplication.shared.isIdleTimerDisabled = AppSettings.shared.keepScreenOn
            }
            .onDisappear {
                viewModel.saveProgress()
                ttsManager.stop()
                autoPageTurnManager.stop()
                readingEnhancementManager.endReadingSession()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: viewModel.currentPageIndex) { _ in
                autoPageTurnManager.reset()
            }
            .alert("阅读提醒", isPresented: Binding(
                get: { readingEnhancementManager.showReminder },
                set: { newValue in
                    if !newValue {
                        readingEnhancementManager.dismissReminder()
                    }
                }
            )) {
                Button("知道了") {
                    readingEnhancementManager.dismissReminder()
                }
            } message: {
                Text("阅读一段时间了，休息一下眼睛。")
            }
            .sheet(isPresented: $showingChapterList) {
                ChapterListView(viewModel: viewModel, book: book)
            }
            .sheet(isPresented: $showingChangeSource) {
                ChangeSourceSheet(isPresented: $showingChangeSource, book: book) {
                    viewModel.loadBook(book)
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarkSheet(viewModel: viewModel, book: book)
            }
            .sheet(isPresented: $showingBookDetail) {
                NavigationStack { BookDetailView(book: book) }
            }
            .sheet(isPresented: $showingSearchContent) {
                SearchContentView(book: book, isPresented: $showingSearchContent) { chapterIndex, pageIndex in
                    showingSearchContent = false
                    Task {
                        try? await viewModel.loadChapter(at: chapterIndex, restorePageIndex: pageIndex)
                    }
                }
            }
            .sheet(isPresented: $showingContentEdit) {
                if let chapter = viewModel.currentChapter {
                    ContentEditSheet(isPresented: $showingContentEdit, chapter: chapter, onSave: {
                        Task { await viewModel.reloadCurrentChapter() }
                    })
                }
            }
            .confirmationDialog("缓存", isPresented: $showingCacheRange, titleVisibility: .visible) {
                Button("后面50章") { Task { await viewModel.cacheRange(count: 50) } }
                Button("后面100章") { Task { await viewModel.cacheRange(count: 100) } }
                Button("后面全部") { Task { await viewModel.cacheEntireBook() } }
                Button("取消", role: .cancel) {}
            }
            .alert("翻页区域", isPresented: $showingPageTutorial) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("点击屏幕左侧：上一页\n点击屏幕中间：呼出/隐藏菜单\n点击屏幕右侧：下一页")
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI || statusBarStatus == 0)
    }
}

// MARK: - 底部面板按钮（真版深色面板：图标+文字白色）

struct ReaderBottomPanelButton: View {
    let image: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                XSGReaderIcon(name: image, size: 23)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 工具栏按钮组件
struct ToolBarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.primary)
        }
    }
}

// MARK: - 旧分页视图（保留向后兼容）
struct ReaderPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    
    var body: some View {
        PagedReaderView(viewModel: viewModel) {
            // 默认无操作
        }
    }
}

#Preview {
    Text("ReaderView Preview")
}
