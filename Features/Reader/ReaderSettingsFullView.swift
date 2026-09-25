//
//  ReaderSettingsFullView.swift
//  Legado-iOS
//
//  完整阅读设置界面
//

import SwiftUI

struct ReaderSettingsFullView: View {

    @AppStorage("tr_showTime") private var showTime = false
    @AppStorage("tr_showBatView") private var showBattery = false
    @AppStorage("tr_showFProgress") private var showFullProgress = false
    @AppStorage("tr_showCpTitle") private var showCpTitle = true
    @AppStorage("tr_showProgress") private var showProgress = true
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var appSettings = AppSettings.shared

    @AppStorage("reader.fontSize") private var storedFontSize: Double = 20
    @AppStorage("reader.lineSpacing") private var storedLineSpacing: Double = 10
    @AppStorage("reader.paragraphSpacing") private var storedParagraphSpacing: Double = 14
    @AppStorage("reader.pageMargin") private var storedPageMargin: Double = 20
    @AppStorage("reader.brightness") private var storedBrightness: Double = 1.0
    @AppStorage("reader.theme") private var storedTheme: String = ReaderThemeType.light.rawValue
    @AppStorage("pageAnimation") private var storedPageAnimation: String = PageAnimation.cover.rawValue
    @AppStorage("reader.fontName") private var storedFontFamily: String = ""
    @AppStorage("reader.showStatusBar") private var storedShowStatusBar: Bool = false
    @AppStorage("reader.clickToFlip") private var storedClickToFlip: Bool = true
    @AppStorage("tr_speakType") private var speakType = 0
    @AppStorage("fanjianZi") private var textConversion = 0
    @AppStorage("tr_autoDarkModel") private var autoDarkModel = false
    @AppStorage("tr_autoHomeIndicator") private var autoHomeIndicator = true
    @AppStorage("r_statusBarStatus") private var statusBarStatus = 0
    @AppStorage("r_popGestureType") private var popGestureType = 2
    
    // 阅读配置
    @State private var fontSize: Double = 20
    @State private var lineSpacing: Double = 10
    @State private var paragraphSpacing: Double = 14
    @State private var pageMargin: Double = 20
    @State private var brightness: Double = 1.0
    @State private var theme: ReaderThemeType = .light
    @State private var pageAnimation: PageAnimation = .cover
    @State private var fontFamily: String = ""
    @State private var showStatusBar = false
    @State private var clickToFlip = true
    
    enum ReaderThemeType: String, CaseIterable, Identifiable {
        case light = "亮色"
        case dark = "暗色"
        case sepia = "羊皮纸"
        case eyeProtection = "护眼"
        case custom = "自定义"
        
        var id: String { self.rawValue }
    }
    
    enum PageAnimation: String, CaseIterable, Identifiable {
        case cover = "覆盖"
        case simulation = "仿真"
        case slide = "滑动"
        case scroll = "滚动"
        case none = "无动画"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        Form {
                Section(header: Text("主题")) {
                    Picker("主题", selection: $theme) {
                        ForEach(ReaderThemeType.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if theme == .custom {
                        ColorPicker("背景颜色", selection: .constant(.white))
                        ColorPicker("文字颜色", selection: .constant(.black))
                    }
                }
                
                Section(header: Text("字体")) {
                    Stepper("字号：\(Int(fontSize))", value: $fontSize, in: 12...32, step: 1)
                    
                    Stepper("行距：\(Int(lineSpacing))", value: $lineSpacing, in: 4...20, step: 1)
                    
                    Stepper("段距：\(Int(paragraphSpacing))", value: $paragraphSpacing, in: 0...30, step: 2)
                    
                    Picker("字体", selection: $fontFamily) {
                        Text("系统").tag("")
                        Text("宋体").tag("Songti SC")
                        Text("黑体").tag("Heiti SC")
                        Text("楷体").tag("Kaiti SC")
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("翻页")) {
                    Picker("翻页动画", selection: $pageAnimation) {
                        ForEach(PageAnimation.allCases) { anim in
                            Text(anim.rawValue).tag(anim)
                        }
                    }
                    
                    Toggle("点击翻页", isOn: $clickToFlip)
                }

                Section(header: Text("阅读行为")) {
                    Picker("朗读模式", selection: $speakType) {
                        Text("按页朗读").tag(0)
                        Text("按章朗读").tag(1)
                    }

                    Picker("繁简转换", selection: $textConversion) {
                        Text("保持原文").tag(0)
                        Text("简体").tag(1)
                        Text("繁体").tag(2)
                    }

                    Toggle("阅读时自动深色模式", isOn: $autoDarkModel)
                    Toggle("阅读时自动隐藏小横条", isOn: $autoHomeIndicator)

                    Picker("顶部状态栏", selection: $statusBarStatus) {
                        Text("不显示").tag(0)
                        Text("白色状态栏").tag(1)
                        Text("黑色状态栏").tag(3)
                    }

                    Picker("侧滑返回", selection: $popGestureType) {
                        Text("禁用").tag(0)
                        Text("防误触").tag(1)
                        Text("总是开启").tag(2)
                    }
                }
                
                Section(header: Text("显示")) {
                    Stepper("页边距：\(Int(pageMargin))", value: $pageMargin, in: 0...60, step: 4)
                    
                    Slider(value: $brightness, in: 0.5...1.5, step: 0.1) {
                        Text("亮度")
                    }
                    
                    Toggle("显示状态栏", isOn: $showStatusBar)

                    Toggle("显示时间", isOn: $showTime)
                    Toggle("显示电量", isOn: $showBattery)
                    Toggle("显示全书百分比进度", isOn: $showFullProgress)
                    Toggle("显示章节标题", isOn: $showCpTitle)
                    Toggle("显示页面进度", isOn: $showProgress)
                }
                
                Section(header: Text("预览")) {
                    ReaderPreviewView(
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        theme: theme
                    )
                    .frame(height: 200)
                }
                
                Section {
                    Button("恢复默认设置") {
                        resetToDefault()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
    }
    
    private func resetToDefault() {
        fontSize = 20
        lineSpacing = 10
        paragraphSpacing = 14
        pageMargin = 20
        brightness = 1.0
        theme = .light
        pageAnimation = .cover
        fontFamily = ""
    }
    
    private func saveSettings() {
        storedFontSize = fontSize
        storedLineSpacing = lineSpacing
        storedParagraphSpacing = paragraphSpacing
        storedPageMargin = pageMargin
        storedBrightness = brightness
        storedTheme = theme.rawValue
        storedPageAnimation = pageAnimation.rawValue
        storedFontFamily = fontFamily
        storedShowStatusBar = showStatusBar
        storedClickToFlip = clickToFlip

        appSettings.readAloudMode = speakType == 0 ? .byPage : .byChapter
        appSettings.textConversionMode = [TextConversionMode.noConversion, .toSimplified, .toTraditional][min(max(textConversion, 0), 2)]
    }

    private func loadSettings() {
        fontSize = storedFontSize
        lineSpacing = storedLineSpacing
        paragraphSpacing = storedParagraphSpacing
        pageMargin = storedPageMargin
        brightness = storedBrightness
        theme = ReaderThemeType(rawValue: storedTheme) ?? .light
        pageAnimation = PageAnimation(rawValue: storedPageAnimation) ?? .cover
        fontFamily = storedFontFamily
        showStatusBar = storedShowStatusBar
        clickToFlip = storedClickToFlip
        speakType = appSettings.readAloudMode == .byChapter ? 1 : 0
        textConversion = {
            switch appSettings.textConversionMode {
            case .noConversion: return 0
            case .toSimplified: return 1
            case .toTraditional: return 2
            }
        }()
    }
}

// MARK: - 预览视图
struct ReaderPreviewView: View {
    let fontSize: Double
    let lineSpacing: Double
    let theme: ReaderSettingsFullView.ReaderThemeType
    
    var backgroundColor: Color {
        switch theme {
        case .light: return Color(red: 0.976, green: 0.937, blue: 0.867)
        case .dark: return .black
        case .sepia: return Color(red: 0.96, green: 0.91, blue: 0.83)
        case .eyeProtection: return Color(red: 0.75, green: 0.84, blue: 0.71)
        case .custom: return .white
        }
    }
    
    var textColor: Color {
        switch theme {
        case .light: return Color(red: 0.18, green: 0.15, blue: 0.12)
        case .dark: return .white
        case .sepia: return Color(red: 0.33, green: 0.28, blue: 0.22)
        case .eyeProtection: return .black
        case .custom: return .black
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            Text("预览文本")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            Text("""
            这是阅读效果预览。您可以根据个人喜好调整字体大小、行距、段距等参数，以获得最佳的阅读体验。
            
            点击屏幕左侧可返回上一章，点击右侧可进入下一章。点击屏幕中央可显示或隐藏菜单。
            """)
            .font(.system(size: fontSize))
            .foregroundColor(textColor)
            .lineSpacing(lineSpacing)
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        ReaderSettingsFullView()
    }
}
