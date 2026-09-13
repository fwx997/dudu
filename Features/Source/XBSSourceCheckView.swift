//
//  XBSSourceCheckView.swift
//  Legado-iOS
//
//  站点检测独立页（对齐 ConfigSourceCheckVC：逐站结果列表 + 开始/停止）
//

import SwiftUI

struct XBSSourceCheckView: View {
    @ObservedObject var store: XBSSourceStore

    var body: some View {
        List {
            ForEach(store.sources) { source in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.sourceName)
                            .font(.subheadline)
                        Text(source.host)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if store.isChecking {
                        if let status = store.checkStatus[source.alias] {
                            Image(systemName: status == "ok" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(status == "ok" ? .green : .red)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    } else if let status = store.checkStatus[source.alias] {
                        Text(status == "ok" ? "可用" : "失败")
                            .font(.caption)
                            .foregroundColor(status == "ok" ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("检测站点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.isChecking {
                    Button("停止") {
                        store.stopChecking()
                    }
                } else {
                    Button("开始") {
                        Task { await store.checkAll() }
                    }
                }
            }
        }
        .overlay {
            if store.sources.isEmpty {
                Text("暂无站点，请先导入")
                    .foregroundColor(.secondary)
            }
        }
    }
}
