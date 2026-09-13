//
//  SearchFilter.swift
//  Legado-iOS
//
//  搜索过滤工具
//

import Foundation
import SwiftUI

class SearchFilter {
    static let shared = SearchFilter()

    private init() {}

    /// 过滤搜索结果
    func filter<T>(
        _ results: [T],
        keyword: String,
        filterType: SearchFilterType,
        getName: (T) -> String
    ) -> [T] {
        switch filterType {
        case .noFilter:
            return results

        case .matchKeyword:
            return results.filter { result in
                let name = getName(result).lowercased()
                let key = keyword.lowercased()
                return name == key
            }

        case .containsKeyword:
            return results.filter { result in
                let name = getName(result).lowercased()
                let key = keyword.lowercased()
                return name.contains(key)
            }
        }
    }

    /// 按书源类型过滤
    func filterBySourceType(_ sources: [BookSource], sourceType: SourceType) -> [BookSource] {
        switch sourceType {
        case .all:
            return sources
        case .text:
            return sources.filter { $0.bookSourceType == 0 }
        case .image:
            return sources.filter { $0.bookSourceType == 1 }
        case .audio:
            return sources.filter { $0.bookSourceType == 2 }
        case .video:
            return sources.filter { $0.bookSourceType == 3 }
        }
    }

    /// 智能排序搜索结果
    func sortResults<T>(
        _ results: [T],
        keyword: String,
        getName: (T) -> String
    ) -> [T] {
        let key = keyword.lowercased()

        return results.sorted { lhs, rhs in
            let lhsName = getName(lhs).lowercased()
            let rhsName = getName(rhs).lowercased()

            // 完全匹配优先
            let lhsExact = lhsName == key
            let rhsExact = rhsName == key
            if lhsExact != rhsExact {
                return lhsExact
            }

            // 前缀匹配次之
            let lhsPrefix = lhsName.hasPrefix(key)
            let rhsPrefix = rhsName.hasPrefix(key)
            if lhsPrefix != rhsPrefix {
                return lhsPrefix
            }

            // 包含关键字位置靠前的优先
            if let lhsRange = lhsName.range(of: key),
               let rhsRange = rhsName.range(of: key) {
                let lhsDistance = lhsName.distance(from: lhsName.startIndex, to: lhsRange.lowerBound)
                let rhsDistance = rhsName.distance(from: rhsName.startIndex, to: rhsRange.lowerBound)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
            }

            // 名称长度短的优先
            if lhsName.count != rhsName.count {
                return lhsName.count < rhsName.count
            }

            // 字典序
            return lhsName < rhsName
        }
    }

    /// 高亮关键字（返回 AttributedString）
    func highlightKeyword(in text: String, keyword: String) -> AttributedString {
        var attributed = AttributedString(text)

        guard !keyword.isEmpty else { return attributed }

        var searchStart = text.startIndex
        while let range = text.range(of: keyword, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
            if let start = AttributedString.Index(range.lowerBound, within: text),
               let end = AttributedString.Index(range.upperBound, within: text) {
                attributed[start..<end].foregroundColor = .red
                attributed[start..<end].font = .boldSystemFont(ofSize: 16)
            }
            searchStart = range.upperBound
        }

        return attributed
    }
}
