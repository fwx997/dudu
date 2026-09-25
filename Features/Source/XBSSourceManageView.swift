//
//  XBSSourceManageView.swift
//  Legado-iOS
//
//  站点管理（香色闺阁书源/.xbs/.json 导入、启停、删除）
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct XBSSourceManageView: View {
    @StateObject private var store = XBSSourceStore.shared
    @State private var showingNetworkImport = false
    @State private var importURLText = ""
    @State private var statusMessage: String?
    @State private var importing = false
    @State private var showingEditor = false
    @State private var editingSource: XBSSource?

    enum InitialAction { case none, network, clipboard, file, newSource }
    var initialAction: InitialAction = .none
    var canDismiss = false
    @Environment(\.dismiss) private var dismiss
    @State private var didRunInitialAction = false
    @State private var showingImportMenu = false
    @State private var isEditing = false
    @State private var selectedAliases: Set<String> = []
    @State private var confirmingDelete = false
    @State private var confirmingDisabledDelete = false
    @State private var confirmingReset = false

    private var actionSources: [XBSSource] {
        isEditing ? store.sources.filter { selectedAliases.contains($0.alias) } : store.sources
    }

    var body: some View {
        sourceList
            .navigationTitle("书源管理 (\(store.sources.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar { navigationTools }
            .confirmationDialog("导入站点", isPresented: $showingImportMenu, titleVisibility: .visible) {
                networkImportButton
                clipboardImportButton
                localFileImportButton
            }
            .confirmationDialog("删除被选中站点", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("删除 \(selectedAliases.count) 个站点", role: .destructive) { deleteSelection() }
            } message: { Text("书架中的书籍会保留。") }
            .confirmationDialog("删除禁用站点", isPresented: $confirmingDisabledDelete, titleVisibility: .visible) {
                Button("删除禁用站点", role: .destructive) { store.removeDisabled() }
            } message: { Text("书架中的书籍会保留。") }
            .confirmationDialog("重置站点", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("重置站点", role: .destructive) { store.reset() }
            } message: { Text("站点和缓存会被清空，书架中的书籍不会删除。") }
            .alert("网络导入", isPresented: $showingNetworkImport) {
                TextField("站点链接", text: $importURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("导入") { Task { await importFromNetwork() } }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack { XBSSourceEditView(store: store, source: editingSource) }
            }
            .alert("导入结果", isPresented: Binding(
                get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } }
            )) {
                Button("确定", role: .cancel) { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
            .overlay { if importing { ProgressView("正在导入…").padding().background(.regularMaterial) } }
            .task { runInitialAction() }
    }

    private var sourceList: some View {
        List {
            ForEach([SourceType.text, .image, .audio, .video], id: \.rawValue) { type in
                sourceSection(type)
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 44)
        .overlay { if store.sources.isEmpty { emptySources } }
        .safeAreaInset(edge: .bottom) { if isEditing { selectionBar } }
    }

    private var emptySources: some View {
        VStack(spacing: 12) {
            Text("无可用站点").foregroundColor(.secondary)
            Button("导入站点") { showingImportMenu = true }
        }
    }

    @ViewBuilder
    private func sourceSection(_ type: SourceType) -> some View {
        let sources = store.sources.filter { $0.sourceType == type.rawValue }
        if !sources.isEmpty {
            Section(type.displayName) {
                ForEach(sources) { source in sourceRow(source) }
            }
        }
    }

    private func sourceRow(_ source: XBSSource) -> some View {
        Button { selectSource(source) } label: {
            sourceLabel(source)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
        .onLongPressGesture { isEditing = true; selectedAliases.insert(source.alias) }
        .swipeActions {
            Button(source.enabled ? "禁用" : "启用") { store.setEnabled(source.alias, enabled: !source.enabled) }
                .tint(.orange)
        }
    }

    private func sourceLabel(_ source: XBSSource) -> some View {
        HStack(spacing: 10) {
            if isEditing {
                Image(systemName: selectedAliases.contains(source.alias) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.accentColor)
            }
            Text(source.sourceName).foregroundColor(source.enabled ? .primary : .secondary)
            Spacer()
            if let status = store.checkStatus[source.alias] {
                Image(systemName: status == "ok" ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.caption).foregroundColor(status == "ok" ? .secondary : .red)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
        .font(.system(size: 16))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ToolbarContentBuilder
    private var navigationTools: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if canDismiss { Button("返回") { dismiss() } }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button("同步") { showingImportMenu = true }
                Menu("更多") { moreActions }
            }
            .font(.system(size: 16))
        }
    }

    @ViewBuilder
    private var moreActions: some View {
        newSiteButton
        Button(isEditing ? "完成编辑" : "选择站点") { isEditing.toggle(); selectedAliases.removeAll() }
        exportButton.disabled(actionSources.isEmpty)
        Button("反转可用性") { toggleAvailability() }.disabled(actionSources.isEmpty)
        Button("删除被选中站点", role: .destructive) { confirmingDelete = true }
            .disabled(selectedAliases.isEmpty)
        Button("删除禁用站点", role: .destructive) { confirmingDisabledDelete = true }
            .disabled(!store.sources.contains { !$0.enabled })
        Button("重置站点", role: .destructive) { confirmingReset = true }
            .disabled(store.sources.isEmpty)
        checkPageLink
        Divider()
        networkImportButton
        clipboardImportButton
        localFileImportButton
        searchSiteLinks
    }

    private var selectionBar: some View {
        HStack {
            Button("全选") { selectedAliases = Set(store.sources.map(\.alias)) }
            Spacer()
            Text("已选 \(selectedAliases.count) 个").foregroundColor(.secondary)
            Spacer()
            Button("完成") { isEditing = false; selectedAliases.removeAll() }
        }
        .font(.subheadline).padding(14).background(.bar)
    }

    private func selectSource(_ source: XBSSource) {
        guard isEditing else { editingSource = source; showingEditor = true; return }
        if selectedAliases.contains(source.alias) { selectedAliases.remove(source.alias) }
        else { selectedAliases.insert(source.alias) }
    }

    private func deleteSelection() {
        for alias in selectedAliases { store.remove(alias) }
        selectedAliases.removeAll()
        isEditing = false
    }

    private func toggleAvailability() {
        for source in actionSources { store.setEnabled(source.alias, enabled: !source.enabled) }
    }

    private func runInitialAction() {
        guard !didRunInitialAction else { return }
        didRunInitialAction = true
        switch initialAction {
        case .none: break
        case .network: showingNetworkImport = true
        case .clipboard: importFromClipboard()
        case .file: openXBSFilePicker()
        case .newSource: editingSource = nil; showingEditor = true
        }
    }

    // MARK: - 导入

    // MARK: - 导出

    /// 导出全部站点为临时 .xbs 文件（与香色闺阁格式互通）
    private func exportURL() -> URL {
        let data = XBSSourceFile.exportXBS(sources: actionSources)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dudu_站点备份.xbs")
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func importFromClipboard() {
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            statusMessage = "剪贴板是空的，请先复制书源链接或 JSON"
            return
        }
        importing = true
        Task {
            defer { importing = false }
            // 形态一：书源链接
            if text.hasPrefix("http"), let url = URL(string: text) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let sources = try XBSSourceFile.parse(data: data)
                    let added = store.importSources(sources)
                    statusMessage = "导入成功：共 \(sources.count) 个站点，新增 \(added) 个"
                } catch {
                    statusMessage = "导入失败：\(error.localizedDescription)"
                }
                return
            }
            // 形态二：剪贴板里直接是 JSON / base64 xbs
            do {
                let sources = try XBSSourceFile.parse(data: Data(text.utf8))
                let added = store.importSources(sources)
                statusMessage = "导入成功：共 \(sources.count) 个站点，新增 \(added) 个"
            } catch {
                statusMessage = "剪贴板内容不是有效的书源（支持链接/.xbs/JSON）"
            }
        }
    }

    private func importFromNetwork() async {
        let trimmed = importURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), trimmed.hasPrefix("http") else {
            statusMessage = "链接格式不正确"
            return
        }
        importing = true
        defer { importing = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sources = try XBSSourceFile.parse(data: data)
            let added = store.importSources(sources)
            statusMessage = "导入成功：共 \(sources.count) 个站点，新增 \(added) 个"
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func importFromFile(url: URL) async {
        importing = true
        defer { importing = false }
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let sources = try XBSSourceFile.parse(data: data)
            let added = store.importSources(sources)
            statusMessage = "导入成功：共 \(sources.count) 个站点，新增 \(added) 个"
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        XBSSourceManageView()
    }
}


extension XBSSourceManageView {

    private var newSiteButton: some View {
        Button {
            editingSource = nil
            showingEditor = true
        } label: {
            Label("新建站点", systemImage: "square.and.pencil")
        }
    }

    private var checkPageLink: some View {
        NavigationLink {
            XBSSourceCheckView(store: store)
        } label: {
            Label("检测站点", systemImage: "list.bullet.rectangle")
        }
    }

    private var networkImportButton: some View {
        Button {
            importURLText = ""
            showingNetworkImport = true
        } label: {
            Label("网络导入", systemImage: "network")
        }
    }

    private var clipboardImportButton: some View {
        Button {
            importFromClipboard()
        } label: {
            Label("剪贴板导入", systemImage: "doc.on.clipboard")
        }
    }

    private var localFileImportButton: some View {
        Button {
            openXBSFilePicker()
        } label: {
            Label("本地文件导入", systemImage: "doc")
        }
    }

    private var checkAllButton: some View {
        Button {
            Task { await store.checkAll() }
        } label: {
            Label("检测全部站点", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    private var exportButton: some View {
        ShareLink(item: exportURL(), preview: SharePreview("站点备份.xbs")) {
            Label("导出站点", systemImage: "square.and.arrow.up")
        }
    }

    private var searchSiteLinks: some View {
        Section("搜索站点") {
            Link(destination: URL(string: "https://search.gitee.com/?q=%e9%a6%99%e8%89%b2%e9%97%ba%e9%98%81&skin=rec&type=none&sort=stars_count")!) {
                Label("gitee", systemImage: "safari")
            }
            Link(destination: URL(string: "https://github.com/search?q=%E9%A6%99%E8%89%B2%E9%97%BA%E9%98%81&s=stars")!) {
                Label("github", systemImage: "safari")
            }
            Link(destination: URL(string: "https://www.baidu.com/s?wd=%E9%A6%99%E8%89%B2%E9%97%BA%E9%98%81")!) {
                Label("baidu", systemImage: "safari")
            }
        }
    }

    private func openXBSFilePicker() {
        DocumentPickerHelper.shared.present(contentTypes: [.data]) { urls in
            guard let url = urls.first else { return }
            Task { await importFromFile(url: url) }
        }
    }
}
