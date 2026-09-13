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
    @State private var showingFileImporter = false
    @State private var statusMessage: String?
    @State private var importing = false

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
        .navigationTitle("站点管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        importURLText = ""
                        showingNetworkImport = true
                    } label: {
                        Label("网络导入", systemImage: "network")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("本地文件导入", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if importing {
                ProgressView("正在导入...")
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
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.data]) { result in
            switch result {
            case .success(let url):
                Task { await importFromFile(url: url) }
            case .failure:
                break
            }
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
