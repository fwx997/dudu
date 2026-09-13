//
//  SearchHotWordsManager.swift
//  Legado-iOS
//
//  搜索热词管理
//

import Foundation

class SearchHotWordsManager {
    static let shared = SearchHotWordsManager()

    private let hotWordsKey = "search_hot_words"
    private let lastUpdateKey = "search_hot_words_last_update"
    private let updateInterval: TimeInterval = 86400 // 24小时

    private init() {
        loadDefaultHotWords()
    }

    var hotWords: [String] {
        UserDefaults.standard.stringArray(forKey: hotWordsKey) ?? defaultHotWords
    }

    private var defaultHotWords: [String] {
        [
            "修仙", "都市", "玄幻", "言情", "科幻",
            "历史", "武侠", "游戏", "悬疑", "恐怖"
        ]
    }

    /// 加载默认热词
    private func loadDefaultHotWords() {
        if UserDefaults.standard.array(forKey: hotWordsKey) == nil {
            UserDefaults.standard.set(defaultHotWords, forKey: hotWordsKey)
        }
    }

    /// 更新热词（可从服务器获取）
    func update(_ words: [String]) {
        UserDefaults.standard.set(words, forKey: hotWordsKey)
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }

    /// 是否需要更新
    var needsUpdate: Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) > updateInterval
    }

    /// 重置为默认热词
    func resetToDefault() {
        UserDefaults.standard.set(defaultHotWords, forKey: hotWordsKey)
    }
}
