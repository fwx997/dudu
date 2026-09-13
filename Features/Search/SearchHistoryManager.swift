//
//  SearchHistoryManager.swift
//  Legado-iOS
//
//  搜索历史管理
//

import Foundation

class SearchHistoryManager {
    static let shared = SearchHistoryManager()

    private let maxHistoryCount = 20
    private let historyKey = "search_history"

    private init() {}

    var history: [String] {
        UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    /// 添加搜索历史
    func add(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = history

        // 移除重复项
        current.removeAll { $0 == trimmed }

        // 插入到最前面
        current.insert(trimmed, at: 0)

        // 限制数量
        if current.count > maxHistoryCount {
            current = Array(current.prefix(maxHistoryCount))
        }

        UserDefaults.standard.set(current, forKey: historyKey)
    }

    /// 删除指定历史项
    func remove(_ keyword: String) {
        var current = history
        current.removeAll { $0 == keyword }
        UserDefaults.standard.set(current, forKey: historyKey)
    }

    /// 清空所有历史
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
