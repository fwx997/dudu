//
//  ReplaceRuleDebugView.swift
//  Legado-iOS
//
//  替换规则调试工具
//

import SwiftUI

struct ReplaceRuleDebugView: View {
    @StateObject private var viewModel = ReplaceRuleDebugViewModel()
    
    var body: some View {
        List {
            // 规则输入区
            Section(header: Text("规则设置")) {
                TextField("规则名称", text: $viewModel.ruleName)
                
                TextField("匹配模式", text: $viewModel.pattern)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                TextField("替换内容", text: $viewModel.replacement)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Toggle("正则表达式", isOn: $viewModel.isRegex)
                
                if viewModel.isRegex {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("正则语法提示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• . 匹配任意字符")
                        Text("• \\s+ 匹配空白字符")
                        Text("• .*? 非贪婪匹配")
                        Text("• [a-z] 字符范围")
                        Text("• ^ $ 行首行尾")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 测试文本区
            Section(header: Text("测试文本")) {
                TextEditor(text: $viewModel.testInput)
                    .frame(minHeight: 120)
                    .font(.body)
            }
            
            // 测试结果区
            Section(header: Text("测试结果")) {
                if viewModel.testOutput.isEmpty {
                    Text("点击上方按钮开始测试")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    TextEditor(text: .constant(viewModel.testOutput))
                        .frame(minHeight: 120)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                if viewModel.matchCount > 0 {
                    Label("匹配 \(viewModel.matchCount) 处", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // 操作按钮
            Section {
                Button(action: { viewModel.testRule() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("测试规则")
                    }
                }
                .disabled(viewModel.pattern.isEmpty)
                
                Button(action: { viewModel.clearAll() }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("清空所有")
                    }
                    .foregroundColor(.red)
                }
                
                Button(action: { viewModel.loadExample() }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("加载示例")
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // 常用规则示例
            Section(header: Text("常用规则示例")) {
                ForEach(viewModel.commonRules) { rule in
                    Button(action: { viewModel.applyExample(rule) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(rule.pattern) → \(rule.replacement.isEmpty ? "(删除)" : rule.replacement)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("规则调试")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ViewModel
@MainActor
class ReplaceRuleDebugViewModel: ObservableObject {
    @Published var ruleName = ""
    @Published var pattern = ""
    @Published var replacement = ""
    @Published var isRegex = true
    @Published var testInput = ""
    @Published var testOutput = ""
    @Published var matchCount = 0
    
    let commonRules: [ExampleRule] = [
        ExampleRule(name: "删除空白行", pattern: "\\n\\s*\\n", replacement: "\\n", isRegex: true),
        ExampleRule(name: "删除 HTML 标签", pattern: "<[^>]+>", replacement: "", isRegex: true),
        ExampleRule(name: "合并多个空格", pattern: "\\s+", replacement: " ", isRegex: true),
        ExampleRule(name: "删除广告文本", pattern: "广告|推广|赞助商", replacement: "", isRegex: true),
        ExampleRule(name: "替换繁体字", pattern: "臺", replacement: "台", isRegex: false),
        ExampleRule(name: "删除版权声明", pattern: "©|版权所有|All Rights Reserved", replacement: "", isRegex: true),
        ExampleRule(name: "标准化引号", pattern: "[\u{201c}\u{201d}]", replacement: "\"", isRegex: true),
        ExampleRule(name: "删除 URL", pattern: "https?://[^\\s]+", replacement: "", isRegex: true)
    ]
    
    func testRule() {
        guard !pattern.isEmpty else { return }
        
        let engine = ReplaceEngine.shared
        testOutput = engine.testRule(
            pattern: pattern,
            replacement: replacement,
            isRegex: isRegex,
            testText: testInput
        )
        
        // 计算匹配数
        if isRegex, let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: testInput, range: NSRange(testInput.startIndex..., in: testInput))
            matchCount = matches.count
        } else {
            matchCount = testInput.components(separatedBy: pattern).count - 1
        }
    }
    
    func clearAll() {
        ruleName = ""
        pattern = ""
        replacement = ""
        testInput = ""
        testOutput = ""
        matchCount = 0
    }
    
    func loadExample() {
        testInput = """
第一章 开始

这是正文内容，包含一些广告文字。

广告：购买我们的产品！

继续正文...访问 https://example.com 获取更多信息。

版权声明 © 2024 All Rights Reserved.

台湾是中国的一部分。

结束。
"""
    }
    
    func applyExample(_ rule: ExampleRule) {
        ruleName = rule.name
        pattern = rule.pattern
        replacement = rule.replacement
        isRegex = rule.isRegex
        testRule()
    }
}

// MARK: - 示例规则模型
struct ExampleRule: Identifiable {
    let id = UUID()
    let name: String
    let pattern: String
    let replacement: String
    let isRegex: Bool
}

// MARK: - 预览
#Preview {
    NavigationView {
        ReplaceRuleDebugView()
    }
}