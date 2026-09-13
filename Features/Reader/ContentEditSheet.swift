//
//  ContentEditSheet.swift
//  Legado-iOS
//
//  章节内容编辑 - 参考 Android ContentEditDialog
//  阅读中可编辑当前章节文本内容
//

import SwiftUI
import CoreData

struct ContentEditSheet: View {
    @Binding var isPresented: Bool
    let chapter: BookChapter
    let onSave: () -> Void
    
    @State private var editedContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var hasChanges: Bool = false
    @State private var filterPattern: String = ""
    @State private var filterReplacement: String = ""
    @State private var filterMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载中...")
                } else {
                    // 正则净化（对齐 TextReadFilterVC）
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            TextField("正则表达式，如 广告.*?尾", text: $filterPattern)
                                .textFieldStyle(.roundedBorder)
                            TextField("替换为(可空)", text: $filterReplacement)
                                .textFieldStyle(.roundedBorder)
                            Button("应用") {
                                applyRegexFilter()
                            }
                            .disabled(filterPattern.isEmpty)
                        }
                        .font(.caption)
                        if let filterMessage {
                            Text(filterMessage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    TextEditor(text: $editedContent)
                        .font(.system(.body, design: .serif))
                        .padding()
                        .onChange(of: editedContent) { _ in
                            hasChanges = editedContent != originalContent
                        }
                }
            }
            .navigationTitle("编辑内容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("重置") {
                            editedContent = originalContent
                            hasChanges = false
                        }
                        .disabled(editedContent == originalContent)
                        
                        Button("保存") {
                            saveContent()
                        }
                        .disabled(!hasChanges)
                        .fontWeight(.bold)
                    }
                }
            }
            .alert("有未保存的更改", isPresented: .constant(hasChanges && !isPresented)) {
                Button("放弃更改", role: .destructive) {
                    isPresented = false
                }
                Button("继续编辑", role: .cancel) {}
            }
            .onAppear {
                loadContent()
            }
        }
    }
    
    private func loadContent() {
        isLoading = true
        
        Task {
            // 从缓存加载章节内容
            if let cachedPath = chapter.cachePath,
               let cachedContent = try? String(contentsOfFile: cachedPath, encoding: .utf8) {
                editedContent = cachedContent
                originalContent = cachedContent
            } else if let contentHash = chapter.contentHash {
                // 尝试从其他存储加载
                editedContent = "无法加载章节内容"
                originalContent = ""
            } else {
                editedContent = "章节内容尚未缓存"
                originalContent = ""
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func applyRegexFilter() {
        guard let regex = try? NSRegularExpression(pattern: filterPattern) else {
            filterMessage = "正则表达式无效"
            return
        }
        let ns = editedContent as NSString
        editedContent = regex.stringByReplacingMatches(in: editedContent, range: NSRange(location: 0, length: ns.length), withTemplate: filterReplacement)
        filterMessage = "已应用替换"
        hasChanges = editedContent != originalContent
    }

    private func saveContent() {
        // 保存到缓存文件
        if let cachePath = chapter.cachePath {
            try? editedContent.write(toFile: cachePath, atomically: true, encoding: .utf8)
        } else {
            // 创建新的缓存路径
            let cacheDir = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first!.appendingPathComponent("ChapterCache")
            
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            let filePath = cacheDir.appendingPathComponent("\(chapter.chapterId.uuidString).txt").path
            try? editedContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            
            let context = chapter.managedObjectContext
            context?.perform {
                chapter.cachePath = filePath
                try? context?.save()
            }
        }
        
        onSave()
        isPresented = false
    }
}