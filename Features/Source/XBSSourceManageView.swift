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

    var body: some View {
        Group {
            if store.sources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("还没有站点")
                        .font(.headline)
                    Text("点击右上角 + 导入 .xbs / .json 书源\n支持粘贴书源链接或导入本地文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.sources) { source in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(source.sourceName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(source.typeName)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(source.typeName == "文本" ? Color.blue : Color.orange)
                                        .cornerRadius(4)

                                    if let status = store.checkStatus[source.alias] {
                                        Text(status == "ok" ? "可用" : "失败")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(status == "ok" ? Color.green : Color.red)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(source.host)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { source.enabled },
                                set: { store.setEnabled(source.alias, enabled: $0) }
                            ))
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingSource = source
                            showingEditor = true
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.remove(store.sources[index].alias)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("书源管理 (\(store.sources.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        Task { await store.checkAll() }
                    } label: {
                        Text("同步").font(.subheadline)
                    }
                    .disabled(store.isChecking || store.sources.isEmpty)
                    Menu {
                        newSiteButton
                        checkPageLink
                        Divider()
                        networkImportButton
                        clipboardImportButton
                        localFileImportButton
                        Divider()
                        checkAllButton
                        exportButton
                        Divider()
                        searchSiteLinks
                    } label: {
                        Text("更多").font(.subheadline)
                    }
                }
            }
        }
        .overlay {
            if importing {
                ProgressView("正在导入...")
            } else if store.isChecking {
                ProgressView("检测中 \(store.checkDone)/\(store.checkTotal)...")
            }
        }
        .alert("网络导入", isPresented: $showingNetworkImport) {
            TextField("粘贴书源链接（.xbs / .json）", text: $importURLText)
            Button("导入") {
                Task { await importFromNetwork() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("支持 .xbs 加密书源与明文 JSON 书源")
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack { XBSSourceEditView(store: store, source: editingSource) }
        }
        .alert("导入结果", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("确定", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    // MARK: - 导入

    // MARK: - 导出

    /// 导出全部站点为临时 .xbs 文件（与香色闺阁格式互通）
    private func exportURL() -> URL {
        let data = XBSSourceFile.exportXBS(sources: store.sources)
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
            Label("导出全部站点（.xbs）", systemImage: "square.and.arrow.up")
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