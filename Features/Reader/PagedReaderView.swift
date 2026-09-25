//
//  PagedReaderView.swift
//  Legado-iOS
//
//  分页阅读容器视图
//  根据用户设置的翻页动画类型切换不同的翻页实现
//

import SwiftUI
import UIKit

struct PagedReaderView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @AppStorage("pageAnimation") var pageAnimationRaw: String = PageAnimationType.cover.rawValue
    let onTap: () -> Void
    
    @State private var pages: [String] = []
    @State private var containerSize: CGSize = .zero

    private var currentPageBinding: Binding<Int> {
        Binding(
            get: { viewModel.currentPageIndex },
            set: { viewModel.currentPageIndex = $0 }
        )
    }
    
    private var pageAnimation: PageAnimationType {
        PageAnimationType(rawValue: pageAnimationRaw) ?? .slide
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                XSGPaperBackground(viewModel: viewModel).ignoresSafeArea()
                
                if pages.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.chapterContent != nil {
                        // 有内容但还没分页（首次加载）
                        ProgressView("分页中...")
                    } else {
                        Text("暂无内容")
                            .foregroundColor(.secondary)
                    }
                } else {
                    pageView
                }
                
                // 页码指示器
                if !pages.isEmpty {
                    VStack {
                        Spacer()
                        pageIndicator
                    }
                }
            }
            .onAppear {
                UIDevice.current.isBatteryMonitoringEnabled = true
                containerSize = geometry.size
                splitPages()
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
                splitPages()
            }
            .onChange(of: viewModel.chapterContent) { _ in
                splitPages()
            }
            .onChange(of: viewModel.fontSize) { _ in
                invalidateAndResplit()
            }
            .onChange(of: viewModel.lineSpacing) { _ in
                invalidateAndResplit()
            }
        }
    }
    
    // MARK: - 翻页视图切换
    
    @ViewBuilder
    private var pageView: some View {
        switch pageAnimation {
        case .cover:
            CoverPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: currentPageBinding,
                onTap: onTap
            )
            
        case .slide:
            SlidePageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: currentPageBinding,
                onTap: onTap
            )
            
        case .scroll:
            scrollView
            
        case .simulation:
            CurlPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: currentPageBinding,
                onTap: onTap
            )
            
        case .none:
            InstantPageView(
                viewModel: viewModel,
                pages: pages,
                currentPage: currentPageBinding,
                onTap: onTap
            )
        }
    }
    
    // MARK: - 滚动视图（保留原有滚动模式）
    
    private var scrollView: some View {
        ScrollView {
            if let content = viewModel.chapterContent {
                Text(content)
                    .font(viewModel.readerFont)
                    .foregroundColor(viewModel.textColor)
                    .lineSpacing(viewModel.lineSpacing)
                    .padding(viewModel.pagePadding)
                    .textSelection(.enabled)
            }
        }
        .background(XSGPaperBackground(viewModel: viewModel))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
    
    // MARK: - 页码指示器
    
    @AppStorage("tr_showTime") private var showTime = true
    @AppStorage("tr_showBatView") private var showBattery = true
    @AppStorage("tr_showCpTitle") private var showCpTitle = true
    @AppStorage("tr_showProgress") private var showProgress = true

    private var batteryText: String {
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? "\(Int(level * 100))%" : "--"
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private var pageIndicator: some View {
        // 真版页脚：左下时间，右下 页码/页数，直接印在纸面上
        HStack(alignment: .bottom) {
            if showTime {
                Text(timeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if showBattery {
                Text(batteryText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 10)
            }
            if showProgress {
                Text("\(min(viewModel.currentPageIndex + 1, pages.count))/\(pages.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, viewModel.pagePadding.leading + 6)
        .padding(.bottom, 6)
    }
    
    // MARK: - 分页逻辑
    
    private func splitPages() {
        guard let content = viewModel.chapterContent, !content.isEmpty else {
            pages = []
            return
        }
        
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        
        let padding = viewModel.pagePadding
        let config = PageConfig.from(
            fontSize: viewModel.fontSize,
            lineSpacing: viewModel.lineSpacing,
            paragraphSpacing: viewModel.paragraphSpacing,
            padding: UIEdgeInsets(
                top: padding.top,
                left: padding.leading,
                bottom: padding.bottom,
                right: padding.trailing
            ),
            containerSize: containerSize,
            fontFamily: viewModel.fontName
        )
        
        // 使用缓存分页
        let result = PageSplitCache.shared.getOrSplit(text: content, config: config)
        
        let oldPage = viewModel.currentPageIndex
        pages = result.pages
        viewModel.totalPages = result.totalPages
        
        // 保持页码在有效范围内
        if oldPage >= pages.count {
            viewModel.currentPageIndex = max(0, pages.count - 1)
        }
    }
    
    private func invalidateAndResplit() {
        PageSplitCache.shared.invalidate()
        splitPages()
    }
}

// MARK: - 翻页动画类型（与 ReaderSettingsFullView.PageAnimation 对齐）

enum PageAnimationType: String, CaseIterable, Identifiable {
    case cover = "覆盖"
    case simulation = "仿真"
    case slide = "滑动"
    case scroll = "滚动"
    case none = "无动画"
    
    var id: String { self.rawValue }
}

// MARK: - 无动画翻页

struct InstantPageView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let pages: [String]
    @Binding var currentPage: Int
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack {
                XSGPaperBackground(viewModel: viewModel)
                
                if currentPage >= 0 && currentPage < pages.count {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(pages[currentPage])
                            .font(viewModel.readerFont)
                            .foregroundColor(viewModel.textColor)
                            .lineSpacing(viewModel.lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(viewModel.pagePadding)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let tapZone = location.x / width
                if tapZone < 0.3 {
                    // 左侧：上一页
                    if currentPage > 0 {
                        currentPage -= 1
                        viewModel.currentPageIndex = currentPage
                    }
                } else if tapZone > 0.7 {
                    // 右侧：下一页
                    if currentPage + 1 < pages.count {
                        currentPage += 1
                        viewModel.currentPageIndex = currentPage
                    }
                } else {
                    // 中间：显示/隐藏 UI
                    onTap()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -50 && currentPage + 1 < pages.count {
                            currentPage += 1
                            viewModel.currentPageIndex = currentPage
                        } else if value.translation.width > 50 && currentPage > 0 {
                            currentPage -= 1
                            viewModel.currentPageIndex = currentPage
                        }
                    }
            )
        }
    }
}
