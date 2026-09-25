//
//  MainTabView.swift
//  Legado-iOS
//
//  主界面容器（对齐香色闺阁真版结构）
//  真版没有底部 TabBar：顶部一行 [文件夹] 书架|发现 [+]，
//  内容区随顶部双标签切换；「我的/设置」经菜单进入。
//

import SwiftUI
import UniformTypeIdentifiers
import StoreKit

// MARK: - 主题（对齐真版：浅色=香色红，深色=蓝色强调）

enum XSGTheme {
    /// 香色闺阁品牌红（图标同款）
    static let brandRed = Color(red: 0.85, green: 0.25, blue: 0.24)
    /// 深色界面下的强调色（真版深色截图为蓝色系）
    static let darkBlue = Color(red: 0.33, green: 0.55, blue: 0.95)

    static func tint(for scheme: ColorScheme) -> Color {
        Color(.systemBlue)
    }
}

// MARK: - 顶部标签状态（书架/发现 共享）

final class MainTabState: ObservableObject {
    static let shared = MainTabState()
    @Published var tab: Int = 0 // 0=书架 1=发现
}

// MARK: - 主容器

struct MainTabView: View {
    @ObservedObject private var tabState = MainTabState.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack { BookshelfView() }
        .tint(XSGTheme.tint(for: colorScheme))
    }
}

// MARK: - 顶部双标签栏（对齐真版首页截图：文件夹 | 书架 发现 | ＋）

struct XSGBTopTabs: View {
    @ObservedObject private var tabState = MainTabState.shared
    var onFolder: () -> Void
    var onSearch: (() -> Void)? = nil
    var onAdd: () -> Void

    var body: some View {
        ZStack {
            Picker("首页", selection: $tabState.tab) {
                Text("书架").tag(0)
                Text("发现").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 116)

            HStack(spacing: 0) {
            Button(action: onFolder) {
                Image(systemName: "folder")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 38, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("书架与配置")

            Spacer()

            if let onSearch {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .frame(width: 34, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("搜索书籍")
            }

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color(.systemBackground))
    }

    private func segmentButton(_ title: String, tag: Int) -> some View {
        let selected = tabState.tab == tag
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { tabState.tab = tag }
        } label: {
            Text(title)
                .font(.system(size: 14.5, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selected ? Color(.systemGray4).opacity(0.9) : Color.clear)
                )
                .foregroundColor(selected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Original PNG artwork extracted from the user-supplied IPA (see docs/ipa-reference).
struct XSGReaderIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image("xsg-reader-" + name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct XSGPaperBackground: View {
    let viewModel: ReaderViewModel

    var body: some View {
        ZStack {
            viewModel.backgroundColor
            if case .light = viewModel.theme {
                Image("xsg-paper-7")
                    .resizable(resizingMode: .tile)
                    .opacity(0.18)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 设置视图（真版入口在加号菜单/抽屉内）

struct SettingsView: View {
    @State private var showingQRScanner = false
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            List {
                // 通用（对齐香色闺阁 plist_settingKeyInfo 常用项）
                Section(header: Label("通用", systemImage: "gearshape")) {
                    Picker("繁简转换", selection: $settings.textConversionMode) {
                        ForEach(TextConversionMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Toggle("阅读时屏幕常亮", isOn: $settings.keepScreenOn)

                    Toggle("自动夜间模式", isOn: $settings.autoNightMode)

                    Toggle("打开书架时检查更新", isOn: $settings.checkUpdateOnOpen)

                    Toggle("启动后继续上次阅读", isOn: $settings.autoRead)
                }

                // 阅读设置
                Section(header: Label("阅读", systemImage: "book")) {
                    NavigationLink("阅读设置") {
                        ReaderSettingsFullView()
                    }

                    NavigationLink("替换规则") {
                        ReplaceRuleView()
                    }

                    NavigationLink("主题") {
                        ThemeSettingsView()
                    }
                }

                // 数据管理
                Section(header: Label("数据", systemImage: "database")) {
                    NavigationLink("备份与恢复") {
                        BackupRestoreView()
                    }

                    NavigationLink("阅读统计") {
                        ReadingStatisticsView()
                    }

                    NavigationLink("数据迁移") {
                        DataMigrationView()
                    }

                    NavigationLink("词典规则") {
                        DictRuleView()
                    }

                    NavigationLink("清理缓存") {
                        CacheCleanView()
                    }
                }

                // 书源管理
                Section(header: Label("书源", systemImage: "square.grid.2x2")) {
                    NavigationLink("站点管理（香色闺阁源）") {
                        XBSSourceManageView()
                    }

                    NavigationLink("书源管理") {
                        SourceManageView()
                    }

                    NavigationLink("书源订阅") {
                        SourceSubscriptionView()
                    }

                    NavigationLink("书源调试") {
                        SourceDebugView(viewModel: SourceDebugViewModel(source: nil))
                    }

                    Button(action: { showingQRScanner = true }) {
                        HStack {
                            Text("扫码导入书源")
                            Spacer()
                            Image(systemName: "qrcode.viewfinder")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 关于
                Section(header: Label("关于", systemImage: "info.circle")) {
                    NavigationLink("关于") {
                        AboutView()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScanView()
            }
        }
    }
}

// MARK: - 关于视图（对齐 AboutController：去评分/版本更新/联系我们/发送日志/分享App/免责声明）

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    @State private var showingUpdateAlert = false
    @State private var updateMessage = ""
    @State private var updateURL: URL?

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 44))
                        .foregroundColor(XSGTheme.brandRed)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("香色闺阁").font(.headline)
                        Text("版本 \(versionText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Button("去评分") { requestStoreReview() }
                Button("版本更新") { checkUpdate() }
                Button("联系我们") { contactUs() }
                Button("发送日志") { sendLog() }
                Button("分享App") { shareApp() }
                NavigationLink("免责声明") {
                    DisclaimerView()
                }
            }
            .foregroundColor(.primary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .alert("版本更新", isPresented: $showingUpdateAlert) {
            Button("确定", role: .cancel) {}
            if let url = updateURL {
                Button("前往更新") { openURL(url) }
            }
        } message: {
            Text(updateMessage)
        }
    }

    private func requestStoreReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func checkUpdate() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/fwx997/dudu/releases/latest")!)
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let tag = (obj?["tag_name"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                if Self.isVersion(tag, newerThan: current) {
                    updateMessage = "发现新版本 \(tag)，请前往AppStore更新版本"
                    updateURL = (obj?["html_url"] as? String).flatMap(URL.init(string:))
                } else {
                    updateMessage = "当前已是最新版本"
                    updateURL = nil
                }
            } catch {
                updateMessage = "检查更新失败，请稍后再试"
                updateURL = nil
            }
            showingUpdateAlert = true
        }
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(l.count, r.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func contactUs() {
        openURL(URL(string: "https://github.com/fwx997/dudu/issues")!)
    }

    private func sendLog() {
        // 对齐原版 sendLog：生成“香色闺阁书架日志xsabc”日志文件并分享
        Task { @MainActor in
            let device = UIDevice.current
            let lines = [
                "=== 香色闺阁书架日志 xsabc ===",
                "时间: \(Date())",
                "版本: \(versionText)",
                "系统: \(device.systemName) \(device.systemVersion)",
                "设备: \(device.model)",
                "站点数: \(XBSSourceStore.shared.sources.count)",
                "书架数: \(ShelfStore.shared.shelves.count)"
            ]
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("香色闺阁书架日志xsabc.txt")
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            presentShareSheet(items: [url])
        }
    }

    private func shareApp() {
        presentShareSheet(items: ["https://github.com/fwx997/dudu"])
    }

    private func presentShareSheet(items: [Any]) {
        let share = UIActivityViewController(activityItems: items, applicationActivities: nil)
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first?.present(share, animated: true)
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text("""
            本应用仅供学习交流使用，请勿用于商业目的。

            使用本应用时请遵守相关法律法规，尊重版权。
            应用本身不提供任何内容，所有内容由站点书源提供，站点及内容与开发者无关。

            如确实有需要，请联系开发者获取权限。
            """)
            .font(.callout)
            .lineSpacing(6)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("免责声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 主题设置视图
struct ThemeSettingsView: View {
    @AppStorage("app_theme") private var selectedTheme = "system"

    var body: some View {
        List {
            Section("外观模式") {
                ForEach([
                    ("system", "跟随系统", "iphone"),
                    ("light", "浅色模式", "sun.max"),
                    ("dark", "深色模式", "moon")
                ], id: \.0) { (value, label, icon) in
                    Button(action: { selectedTheme = value }) {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 24)
                                .foregroundColor(.accentColor)
                            Text(label)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTheme == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            Section("阅读背景") {
                ForEach([
                    ("白色", Color.white),
                    ("米黄", Color(red: 0.98, green: 0.95, blue: 0.88)),
                    ("浅绿", Color(red: 0.8, green: 0.93, blue: 0.8)),
                    ("深灰", Color(white: 0.2))
                ], id: \.0) { (name, color) in
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: 40, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        Text(name)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 缓存清理视图
struct CacheCleanView: View {
    @State private var imageCacheSize: String = "计算中..."
    @State private var chapterCacheSize: String = "计算中..."
    @State private var isClearing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section("缓存占用") {
                HStack {
                    Label("图片缓存", systemImage: "photo")
                    Spacer()
                    Text(imageCacheSize)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label("章节缓存", systemImage: "doc.text")
                    Spacer()
                    Text(chapterCacheSize)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: { clearImageCache() }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理图片缓存")
                    }
                }

                Button(action: { clearChapterCache() }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理章节缓存")
                    }
                }

                Button(role: .destructive, action: clearAll) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理全部缓存")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("清理缓存")
        .navigationBarTitleDisplayMode(.inline)
        .task { calculateCacheSize() }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func calculateCacheSize() {
        imageCacheSize = folderSize(imageCacheDir())
        chapterCacheSize = folderSize(chapterCacheDir())
    }

    private func imageCacheDir() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("images", isDirectory: true)
    }

    private func chapterCacheDir() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("chapters", isDirectory: true)
    }

    private func folderSize(_ url: URL?) -> String {
        guard let url = url else { return "0 B" }
        let fm = FileManager.default
        var total: Int64 = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) else {
            return "0 B"
        }

        for case let itemURL as URL in enumerator {
            guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func clearImageCache(showMessage: Bool = true) {
        let dir = imageCacheDir()
        clearDir(dir)
        ImageCacheManager.shared.clearCache()
        calculateCacheSize()

        if showMessage {
            alertMessage = "图片缓存已清理"
            showingAlert = true
        }
    }

    private func clearChapterCache(showMessage: Bool = true) {
        let dir = chapterCacheDir()
        clearDir(dir)
        calculateCacheSize()

        if showMessage {
            alertMessage = "章节缓存已清理"
            showingAlert = true
        }
    }

    private func clearAll() {
        isClearing = true
        defer { isClearing = false }

        clearImageCache(showMessage: false)
        clearChapterCache(showMessage: false)
        alertMessage = "全部缓存已清理"
        showingAlert = true
    }

    private func clearDir(_ url: URL?) {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

struct DataMigrationView: View {
    @StateObject private var manager = DataMigrationManager()
    @State private var selectedType: MigrationType = .legadoAndroid
    @State private var showingImporter = false

    @State private var includeBooks = true
    @State private var includeSources = true
    @State private var includeBookmarks = true
    @State private var includeRules = true
    @State private var showingExporter = false
    @State private var exportDocument = JSONDataDocument()

    var body: some View {
        List {
            Section("导入") {
                Picker("类型", selection: $selectedType) {
                    ForEach(MigrationType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Button("选择文件导入") {
                    showingImporter = true
                }
                .disabled(manager.isMigrating)

                if manager.isMigrating {
                    ProgressView(value: manager.migrationProgress)
                }
            }

            Section("导出") {
                Toggle("包含书籍", isOn: $includeBooks)
                Toggle("包含书源", isOn: $includeSources)
                Toggle("包含书签", isOn: $includeBookmarks)
                Toggle("包含替换规则", isOn: $includeRules)

                Button("导出备份") {
                    exportBackup()
                }
            }

            if let result = manager.migrationResult {
                Section("结果") {
                    Text(result.summary)

                    if !result.errors.isEmpty {
                        Text("错误：")
                            .font(.headline)
                        ForEach(result.errors, id: \.self) { err in
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("数据迁移")
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json, .zip, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { @MainActor in
                    let granted = url.startAccessingSecurityScopedResource()
                    defer {
                        if granted {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    _ = await manager.migrateFromFile(url, type: selectedType)
                }
            case .failure:
                break
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "legado-ios-backup"
        ) { _ in }
    }

    private func exportBackup() {
        guard let data = manager.exportData(
            includeBooks: includeBooks,
            includeSources: includeSources,
            includeBookmarks: includeBookmarks,
            includeRules: includeRules
        ) else {
            return
        }

        exportDocument = JSONDataDocument(data: data)
        showingExporter = true
    }
}

struct JSONDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SourceSubscriptionView: View {
    @StateObject private var manager = SourceSubscriptionManager()
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newUrl = ""

    var body: some View {
        List {
            Section {
                if manager.subscriptions.isEmpty {
                    Text("暂无订阅")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manager.subscriptions) { sub in
                        subscriptionRow(sub)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            manager.removeSubscription(at: index)
                        }
                    }
                }
            } header: {
                Text("订阅列表")
            }

            Section("操作") {
                Button("更新所有订阅") {
                    Task { @MainActor in
                        await manager.updateAllSubscriptions()
                    }
                }

                if manager.isUpdating {
                    ProgressView(value: manager.updateProgress)
                }

                if let err = manager.lastUpdateError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("书源订阅")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("添加订阅", isPresented: $showingAdd) {
            TextField("名称", text: $newName)
            TextField("订阅 URL", text: $newUrl)
                .textInputAutocapitalization(.never)
            Button("取消", role: .cancel) {
                newName = ""
                newUrl = ""
            }
            Button("添加") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = newUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !url.isEmpty {
                    manager.addSubscription(name: name, url: url)
                }
                newName = ""
                newUrl = ""
            }
        }
    }

    @ViewBuilder
    private func subscriptionRow(_ sub: SourceSubscription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sub.name)
                    .font(.headline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { sub.enabled },
                    set: { newValue in
                        var updated = sub
                        updated.enabled = newValue
                        manager.updateSubscription(updated)
                    }
                ))
                .labelsHidden()
            }

            Text(sub.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Toggle("自动更新", isOn: Binding(
                    get: { sub.autoUpdate },
                    set: { newValue in
                        var updated = sub
                        updated.autoUpdate = newValue
                        manager.updateSubscription(updated)
                    }
                ))
                .font(.caption)

                Spacer()

                if let last = sub.lastUpdateTime {
                    Text("上次：\(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("从未更新")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button("立即更新") {
                    Task { @MainActor in
                        try? await manager.updateSubscription(id: sub.id)
                    }
                }
                .font(.caption)

                Spacer()

                Menu {
                    ForEach([3600.0, 21600.0, 43200.0, 86400.0, 172800.0], id: \.self) { seconds in
                        Button("每 \(Int(seconds / 3600)) 小时") {
                            var updated = sub
                            updated.updateInterval = seconds
                            manager.updateSubscription(updated)
                        }
                    }
                } label: {
                    Text("间隔：\(Int(sub.updateInterval / 3600))h")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainTabView()
}
