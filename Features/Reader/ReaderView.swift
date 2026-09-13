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
    @Environment(\.openURL) private var openURL
    
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                viewModel.backgroundColor
                    .ignoresSafeArea()
                
                // 内容区域
                PagedReaderView(viewModel: viewModel) {
                    autoPageTurnManager.handleTouch()
                    withAnimation { showUI.toggle() }
                }
                
                // MARK: - 顶部工具栏（精简版）
                VStack {
                    HStack {
                        Button(action: {
                            viewModel.saveProgress()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(viewModel.currentChapter?.title ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()

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
                                Task { await viewModel.cacheEntireBook() }
                            } label: {
                                Label("缓存全本", systemImage: "arrow.down.circle")
                            }
                            Button {
                                if let url = URL(string: "https://www.baidu.com/s?word=\(book.name)") {
                                    openURL(url)
                                }
                            } label: {
                                Label("百度搜索", systemImage: "safari")
                            }
                            Button {
                                if let url = URL(string: "https://github.com/fwx997/dudu/issues") {
                                    openURL(url)
                                }
                            } label: {
                                Label("报告错误", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }

                        Button(action: { showingChapterList = true }) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: showUI)
                    
                    Spacer()
                    
                    // MARK: - 底部工具栏（分离式）
                    VStack(spacing: 0) {
                        // 进度区域
                        VStack(spacing: 12) {
                            // 章节进度
                            HStack {
                                Text("第\(viewModel.currentChapterIndex + 1)/\(viewModel.totalChapters)章")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(viewModel.currentChapter?.title ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            // 进度滑块
                            Slider(value: Binding(
                                get: { Double(viewModel.currentChapterIndex) },
                                set: { viewModel.jumpToChapter(Int($0)) }
                            ), in: 0...Double(max(1, viewModel.totalChapters - 1)), step: 1)
                            
                            // 翻页控制
                            HStack(spacing: 20) {
                                Button(action: { Task { await viewModel.prevChapter() } }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.title3)
                                        Text("上一章")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(viewModel.currentChapterIndex <= 0)
                                .opacity(viewModel.currentChapterIndex <= 0 ? 0.5 : 1)
                                
                                Divider()
                                    .frame(height: 30)
                                
                                Button(action: { Task { await viewModel.nextChapter() } }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "chevron.right")
                                            .font(.title3)
                                        Text("下一章")
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(viewModel.currentChapterIndex >= viewModel.totalChapters - 1)
                                .opacity(viewModel.currentChapterIndex >= viewModel.totalChapters - 1 ? 0.5 : 1)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 工具栏
                        HStack(spacing: 0) {
                            ToolBarButton(
                                icon: "a.square",
                                title: "设置",
                                action: { showingSettings = true }
                            )
                            
                            ToolBarButton(
                                icon: "speaker.wave.2",
                                title: "朗读",
                                action: { showingTTSControls = true }
                            )
                            
                            ToolBarButton(
                                icon: "timer",
                                title: "自动",
                                action: { showingAutoPageTurn = true }
                            )
                            
                            ToolBarButton(
                                icon: "bookmark",
                                title: "书签",
                                action: { showingBookmarks = true }
                            )
                            
                            ToolBarButton(
                                icon: "arrow.triangle.2.circlepath",
                                title: "换源",
                                action: { showingChangeSource = true }
                            )
                        }
                        .padding(.vertical, 12)
                    }
                    .background(.ultraThinMaterial)
                    .opacity(showUI ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.25), value: showUI)
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
                    guard AppSettings.shared.autoNightMode else { return }
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
            .alert("翻页区域", isPresented: $showingPageTutorial) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("点击屏幕左侧：上一页\n点击屏幕中间：呼出/隐藏菜单\n点击屏幕右侧：下一页")
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showUI)
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