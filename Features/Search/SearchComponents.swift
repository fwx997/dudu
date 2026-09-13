//
//  SearchComponents.swift
//  Legado-iOS
//
//  搜索页共享组件：流式布局、搜索设置面板
//

import SwiftUI

// MARK: - 流式布局（历史/热词标签用）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - 搜索设置面板（过滤方式 + 书源类型，读写全局设置）

struct SearchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            Form {
                Section("搜索结果过滤") {
                    Picker("过滤方式", selection: $settings.searchFilterType) {
                        ForEach(SearchFilterType.allCases, id: \.rawValue) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("书源类型") {
                    Picker("类型", selection: $settings.searchSourceType) {
                        ForEach(SourceType.allCases, id: \.rawValue) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("繁简转换") {
                    Picker("显示转换", selection: $settings.textConversionMode) {
                        ForEach(TextConversionMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("搜索设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
