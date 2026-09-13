//
//  XBSSource.swift
//  Legado-iOS
//
//  香色闺阁书源（站点）模型与本地存储
//  格式：{ "<站点别名>": { sourceName, sourceUrl, sourceType, enable, weight, ...动作配置... } }
//

import Foundation

struct XBSSource: Identifiable, Equatable {
    let alias: String
    var config: [String: Any]

    var id: String { alias }

    var sourceName: String { config.string("sourceName") ?? alias }
    var sourceUrl: String { config.string("sourceUrl") ?? "" }
    var host: String { config.string("host") ?? sourceUrl }
    var sourceType: String { config.string("sourceType") ?? "text" }
    var weight: Int { Int(config.string("weight") ?? "") ?? 0 }
    var enabled: Bool {
        let v = config["enable"]
        if let n = v as? Int { return n != 0 }
        if let s = v as? String { return s == "1" || s == "true" }
        if let b = v as? Bool { return b }
        return true
    }

    var typeName: String {
        switch sourceType {
        case "image": return "漫画"
        case "audio": return "听书"
        case "video": return "视频"
        default: return "文本"
        }
    }

    func action(_ name: String) -> [String: Any]? {
        config.dict(name)
    }

    var httpHeaders: [String: String] {
        let raw = config["httpHeaders"]
        if let dict = raw as? [String: Any] {
            var out: [String: String] = [:]
            for (k, v) in dict { out[k] = "\(v)" }
            return out
        }
        return [:]
    }

    static func == (lhs: XBSSource, rhs: XBSSource) -> Bool {
        lhs.alias == rhs.alias
    }
}

// MARK: - 书源文件解析（支持 .xbs 加密与明文 JSON）

enum XBSSourceFile {
    /// 解析 .xbs / .json 书源文件，返回站点列表
    static func parse(data: Data) throws -> [XBSSource] {
        var json = data
        let plaintextOK = (try? JSONSerialization.jsonObject(with: json)) != nil
        if !plaintextOK {
            // 明文解析失败 → 尝试 xbs 解密
            json = try XXTEA.decode(data)
        }

        guard let obj = try? JSONSerialization.jsonObject(with: json) else {
            throw XXTEAError.decodeFailed
        }

        var sources: [XBSSource] = []
        if let dict = obj as? [String: Any] {
            for (alias, value) in dict {
                if let config = value as? [String: Any], config["sourceName"] != nil {
                    sources.append(XBSSource(alias: alias, config: config))
                }
            }
        } else if let array = obj as? [[String: Any]] {
            for config in array {
                if let name = config.string("sourceName") {
                    sources.append(XBSSource(alias: name, config: config))
                }
            }
        }
        guard !sources.isEmpty else { throw XXTEAError.decodeFailed }
        return sources
    }

    /// 导出为 .xbs（供备份/分享）
    static func exportXBS(sources: [XBSSource]) -> Data {
        var dict: [String: Any] = [:]
        for source in sources {
            dict[source.alias] = source.config
        }
        let json = (try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])) ?? Data()
        return XXTEA.encode(json)
    }
}

// MARK: - 本地存储（Documents/xbs_sources.json）

final class XBSSourceStore: ObservableObject {
    static let shared = XBSSourceStore()

    @Published private(set) var sources: [XBSSource] = []

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("xbs_sources.json")
    }

    private init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            sources = []
            return
        }
        // 存储形态：[{ "alias": ..., "config": {...} }]
        sources = array.compactMap { entry in
            guard let alias = entry.string("alias"),
                  let config = entry.dict("config") else { return nil }
            return XBSSource(alias: alias, config: config)
        }
    }

    private func save() {
        let array: [[String: Any]] = sources.map { ["alias": $0.alias, "config": $0.config] }
        if let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys, .prettyPrinted]) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// 导入站点，返回新增数量
    @discardableResult
    func importSources(_ newSources: [XBSSource]) -> Int {
        var added = 0
        for source in newSources {
            if let index = sources.firstIndex(where: { $0.alias == source.alias }) {
                sources[index] = source
            } else {
                sources.append(source)
                added += 1
            }
        }
        save()
        objectWillChange.send()
        return added
    }

    func setEnabled(_ alias: String, enabled: Bool) {
        guard let index = sources.firstIndex(where: { $0.alias == alias }) else { return }
        sources[index].config["enable"] = enabled ? 1 : 0
        save()
        objectWillChange.send()
    }

    func remove(_ alias: String) {
        sources.removeAll { $0.alias == alias }
        save()
        objectWillChange.send()
    }

    var enabledSources: [XBSSource] {
        sources.filter { $0.enabled && $0.action("searchBook") != nil }
    }

    func source(alias: String) -> XBSSource? {
        sources.first { $0.alias == alias }
    }
}

// MARK: - Dictionary 取值辅助

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        switch self[key] {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return nil
        }
    }

    func dict(_ key: String) -> [String: Any]? {
        self[key] as? [String: Any]
    }

    func int(_ key: String) -> Int? {
        (self[key] as? NSNumber)?.intValue
    }
}
