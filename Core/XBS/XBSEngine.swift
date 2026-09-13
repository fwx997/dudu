//
//  XBSEngine.swift
//  Legado-iOS
//
//  香色闺阁书源执行引擎
//  支持：requestInfo 模板占位符（%@keyWord/%@pageIndex/%@offset/%@filter/%@result）
//        与 @js: 动态请求（config/params 上下文）
//        DOM(XPath) / JSON($.) 解析、`||` 规则回退链、`xpath||@js:` 二段处理
//        搜索/详情/目录/正文 四大链路 + nextPageUrl 分页 + moreKeys 守卫
//

import Foundation
import JavaScriptCore
import libxml2

struct XBSBook {
    var name = ""
    var author = ""
    var cover: String?
    var desc: String?
    var cat: String?
    var status: String?
    var lastChapterTitle: String?
    var updateTime: String?
    var detailUrl = ""
    var sourceAlias = ""
    var sourceName = ""
}

struct XBSChapter {
    var title: String
    var url: String
}

enum XBSError: LocalizedError {
    case actionMissing(String)
    case badRequest
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .actionMissing(let a): return "站点缺少 \(a) 配置"
        case .badRequest: return "请求构建失败"
        case .parseFailed(let m): return "解析失败：\(m)"
        }
    }
}

final class XBSEngine {
    static let shared = XBSEngine()

    /// 硬性分页上限，防止规则缺陷导致死循环
    private static let hardMaxPage = 50

    // MARK: - 搜索

    func search(source: XBSSource, keyword: String, page: Int = 1) async throws -> [XBSBook] {
        guard let action = source.action("searchBook") else {
            throw XBSError.actionMissing("searchBook")
        }
        var params: [String: Any] = ["keyWord": keyword, "pageIndex": page]
        if let filter = action.string("_defaultFilter") { params["filter"] = filter }

        let response = try await fetch(action: action, source: source, params: params)
        let items = try parseList(action: action, response: response, params: params)

        var books: [XBSBook] = []
        for item in items {
            let values = evaluateFields(action: action, item: item, response: response, params: params,
                                        keys: ["bookName", "detailUrl", "url", "author", "cover", "desc", "cat", "status", "lastChapterTitle", "updateTime"])
            let name = values["bookName"] ?? values["url"] ?? ""
            let detail = values["detailUrl"] ?? values["url"] ?? ""
            guard !name.isEmpty else { continue }
            books.append(XBSBook(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                author: (values["author"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                cover: absoluteURL(values["cover"], base: response.url, host: source.host),
                desc: values["desc"],
                cat: values["cat"],
                status: values["status"],
                lastChapterTitle: values["lastChapterTitle"],
                updateTime: values["updateTime"],
                detailUrl: absoluteURL(detail, base: response.url, host: source.host) ?? detail,
                sourceAlias: source.alias,
                sourceName: source.sourceName
            ))
        }

        let skip = action.dict("moreKeys")?.int("skipCount") ?? 0
        if skip > 0, books.count > skip {
            books = Array(books[skip...])
        }
        return books
    }

    // MARK: - 站点检测

    /// 检测站点可用性：跑一次真实搜索，不抛错即视为可用
    func checkSource(source: XBSSource, keyword: String = "我") async -> Bool {
        guard source.action("searchBook") != nil else { return false }
        do {
            _ = try await search(source: source, keyword: keyword, page: 1)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 相关词 (relatedWord)

    /// 搜索无结果时的站点联想词
    func relatedWords(source: XBSSource, keyword: String) async -> [String] {
        guard let action = source.action("relatedWord"), action.string("requestInfo") != nil else { return [] }
        let params: [String: Any] = ["keyWord": keyword, "pageIndex": 1]
        guard let requestInfo = action.string("requestInfo"),
              let built = try? buildRequest(action: action, requestInfo: requestInfo, source: source, params: params),
              let requestURL = URL(string: built.url) else { return [] }
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        for (k, v) in built.headers { request.setValue(v, forHTTPHeaderField: k) }
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return [] }
        let text = WebPageDecoder.decode(data)
        let doc = XPathDocument(html: text, baseURL: built.url)
        guard doc.isUsable, let listRule = action.string("list") else { return [] }
        var words: [String] = []
        let response = Response(url: built.url, text: text, json: nil, document: doc)
        if case .nodes(let nodes) = doc.evaluate(listRule) {
            for node in nodes {
                let wordRule = action.string("word") ?? "//text()"
                let w = evaluateRule(wordRule, item: node, response: response, params: params)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !w.isEmpty { words.append(w) }
            }
        }
        return Array(words.prefix(10))
    }

    // MARK: - 书单（社区书单）

    struct XBSShudan: Identifiable {
        let title: String
        let cover: String?
        let desc: String?
        let detailUrl: String
        let sourceAlias: String
        let sourceName: String
        var id: String { detailUrl }
    }

    /// 书单搜索（searchShudan）
    func searchShudan(source: XBSSource, keyword: String, page: Int = 1) async throws -> [XBSShudan] {
        guard let action = source.action("searchShudan"), action.string("requestInfo") != nil else {
            throw XBSError.actionMissing("searchShudan")
        }
        let params: [String: Any] = ["keyWord": keyword, "pageIndex": page]
        let response = try await fetch(action: action, source: source, params: params)
        let items = try parseList(action: action, response: response, params: params)

        var list: [XBSShudan] = []
        for item in items {
            let values = evaluateFields(action: action, item: item, response: response, params: params,
                                        keys: ["title", "cover", "desc", "detailUrl", "url"])
            let title = values["title"] ?? ""
            let link = values["detailUrl"] ?? values["url"] ?? ""
            guard !title.isEmpty, !link.isEmpty else { continue }
            list.append(XBSShudan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                cover: absoluteURL(values["cover"], base: response.url, host: source.host),
                desc: values["desc"],
                detailUrl: absoluteURL(link, base: response.url, host: source.host) ?? link,
                sourceAlias: source.alias,
                sourceName: source.sourceName
            ))
        }
        return list
    }

    /// 书单详情：书单内的书籍列表（shudanDetail）
    func shudanBooks(source: XBSSource, url: String) async throws -> [XBSBook] {
        guard let action = source.action("shudanDetail") else {
            throw XBSError.actionMissing("shudanDetail")
        }
        var params: [String: Any] = ["queryInfo": ["url": url, "detailUrl": url]]
        params["result"] = url
        let response = try await fetch(action: action, source: source, params: params)
        let items = try parseList(action: action, response: response, params: params)

        var books: [XBSBook] = []
        for item in items {
            let values = evaluateFields(action: action, item: item, response: response, params: params,
                                        keys: ["bookName", "detailUrl", "url", "author", "cover", "desc", "cat", "lastChapterTitle"])
            let name = values["bookName"] ?? values["url"] ?? ""
            let link = values["detailUrl"] ?? values["url"] ?? ""
            guard !name.isEmpty, !link.isEmpty else { continue }
            books.append(XBSBook(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                author: (values["author"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                cover: absoluteURL(values["cover"], base: response.url, host: source.host),
                desc: values["desc"],
                cat: values["cat"],
                status: nil,
                lastChapterTitle: values["lastChapterTitle"],
                updateTime: nil,
                detailUrl: absoluteURL(link, base: response.url, host: source.host) ?? link,
                sourceAlias: source.alias,
                sourceName: source.sourceName
            ))
        }
        return books
    }

    // MARK: - 漫画/听书内容提取

    /// 章节图片列表（漫画源）：content 规则多节点按行拼接后逐行成图
    func chapterImages(source: XBSSource, url: String) async throws -> [String] {
        guard let action = source.action("chapterContent") else {
            throw XBSError.actionMissing("chapterContent")
        }
        let moreKeys = action.dict("moreKeys") ?? [:]
        let maxPage = moreKeys.int("maxPage") ?? 10

        var urls: [String] = []
        var nextURL: String? = url
        var page = 0
        var lastParams: [String: Any] = ["queryInfo": ["url": url, "detailUrl": url]]

        while let current = nextURL, page < min(maxPage, Self.hardMaxPage) {
            page += 1
            var params = lastParams
            params["result"] = current
            params["pageIndex"] = page

            let response = try await fetch(action: action, source: source, params: params)
            let raw = evaluateFields(action: action, item: parseItem(action: action, response: response),
                                     response: response, params: params,
                                     keys: ["content"], joinMultiline: true)["content"] ?? ""
            for line in raw.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.contains("http") || trimmed.hasPrefix("//") else { continue }
                if let imageUrl = absoluteURL(trimmed, base: response.url, host: source.host) {
                    urls.append(imageUrl)
                }
            }

            let nextValues = evaluateFields(action: action, item: parseItem(action: action, response: response), response: response,
                                            params: params, keys: ["nextPageUrl"])
            let next = (nextValues["nextPageUrl"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if next.isEmpty {
                nextURL = nil
            } else {
                nextURL = absoluteURL(next, base: response.url, host: source.host)
                lastParams["lastResponse"] = ["nextPageUrl": nextURL ?? ""]
                lastParams["responseUrl"] = response.url
            }
        }

        guard !urls.isEmpty else { throw XBSError.parseFailed("未提取到图片") }
        return urls
    }

    /// 章节音频地址（听书源）：content 规则取到的首个 http 链接
    func chapterAudioURL(source: XBSSource, url: String) async throws -> URL {
        guard let action = source.action("chapterContent") else {
            throw XBSError.actionMissing("chapterContent")
        }
        let params: [String: Any] = ["result": url, "pageIndex": 1,
                                     "queryInfo": ["url": url, "detailUrl": url]]
        let response = try await fetch(action: action, source: source, params: params)
        let raw = evaluateFields(action: action, item: parseItem(action: action, response: response),
                                 response: response, params: params,
                                 keys: ["content", "url"])["content"] ?? ""

        // 从文本中抠出第一个音频/媒体链接
        guard let regex = try? NSRegularExpression(pattern: "https?://[^\\s\"'<>]+\\.(?:mp3|m4a|aac|wav|ogg|flac|m3u8|mp4)[^\\s\"'<>]*",
                                                   options: [.caseInsensitive]) else {
            throw XBSError.parseFailed("音频链接解析失败")
        }
        let ns = raw as NSString
        if let match = regex.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)),
           let candidate = ns.substring(with: match.range) as String?,
           let audioURL = URL(string: candidate) {
            return audioURL
        }
        // 兜底：整段即链接
        if let audioURL = absoluteURL(raw.trimmingCharacters(in: .whitespacesAndNewlines), base: response.url, host: source.host),
           let url = URL(string: audioURL) {
            return url
        }
        throw XBSError.parseFailed("未找到音频链接")
    }

    // MARK: - 书世界（分类浏览）

    struct XBSCategory: Identifiable, Equatable {
        let name: String
        let value: String
        var id: String { name }
    }

    /// 解析站点分类：优先 moreKeys.requestFilters（"名称::值" 行式），其次命名子字典
    func bookWorldCategories(source: XBSSource) -> [XBSCategory] {
        guard let action = source.action("bookWorld") else { return [] }

        // 形态一：requestFilters 行式 "玄幻::xuanhuan"
        let filterText = action.dict("moreKeys")?.string("requestFilters")
            ?? action.string("requestFilters") ?? ""
        var categories: [XBSCategory] = []
        for line in filterText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "::")
            if parts.count >= 2 {
                categories.append(XBSCategory(name: parts[0].trimmingCharacters(in: .whitespaces),
                                              value: parts[1].trimmingCharacters(in: .whitespaces)))
            } else {
                categories.append(XBSCategory(name: trimmed, value: trimmed))
            }
        }
        if !categories.isEmpty { return categories }

        // 形态二：命名子字典 { "玄幻": {requestInfo...}, "都市": {...} }
        let reserved = ["actionID", "parserID", "requestInfo", "list", "moreKeys", "validConfig",
                        "responseFormatType", "httpHeaders", "host"]
        for (key, value) in action {
            guard !reserved.contains(key), let sub = value as? [String: Any], sub["requestInfo"] != nil else { continue }
            categories.append(XBSCategory(name: key, value: key))
        }
        return categories
    }

    /// 分类页书籍列表（分页）
    func bookWorld(source: XBSSource, category: XBSCategory?, page: Int) async throws -> [XBSBook] {
        guard var action = source.action("bookWorld") else {
            throw XBSError.actionMissing("bookWorld")
        }

        // 命名子字典形态：取分类专属配置，与公共字段合并
        if let category, let sub = action[category.value] as? [String: Any], sub["requestInfo"] != nil {
            var merged = action
            for (k, v) in sub { merged[k] = v }
            merged["requestInfo"] = sub["requestInfo"]
            action = merged
        }

        var params: [String: Any] = ["pageIndex": page]
        if let category { params["filter"] = category.value }

        let response = try await fetch(action: action, source: source, params: params)
        let items = try parseList(action: action, response: response, params: params)

        var books: [XBSBook] = []
        for item in items {
            let values = evaluateFields(action: action, item: item, response: response, params: params,
                                        keys: ["bookName", "detailUrl", "url", "author", "cover", "desc", "cat", "status", "lastChapterTitle", "updateTime"])
            let name = values["bookName"] ?? values["url"] ?? ""
            let detail = values["detailUrl"] ?? values["url"] ?? ""
            guard !name.isEmpty, !detail.isEmpty else { continue }
            books.append(XBSBook(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                author: (values["author"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                cover: absoluteURL(values["cover"], base: response.url, host: source.host),
                desc: values["desc"],
                cat: values["cat"],
                status: values["status"],
                lastChapterTitle: values["lastChapterTitle"],
                updateTime: values["updateTime"],
                detailUrl: absoluteURL(detail, base: response.url, host: source.host) ?? detail,
                sourceAlias: source.alias,
                sourceName: source.sourceName
            ))
        }
        return books
    }

    // MARK: - 书籍详情

    func bookDetail(source: XBSSource, url: String) async throws -> XBSBook {
        guard let action = source.action("bookDetail") else {
            // 没有详情配置时直接用搜索结果信息
            return XBSBook(detailUrl: url, sourceAlias: source.alias, sourceName: source.sourceName)
        }
        var params: [String: Any] = [
            "queryInfo": ["url": url, "detailUrl": url],
        ]
        params["result"] = url
        let response = try await fetch(action: action, source: source, params: params)
        let values = evaluateFields(action: action, item: parseItem(action: action, response: response), response: response, params: params,
                                    keys: ["title", "bookName", "cover", "desc", "author", "cat", "status", "lastChapterTitle", "updateTime"])
        let name = values["title"] ?? values["bookName"] ?? ""
        return XBSBook(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            author: (values["author"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            cover: absoluteURL(values["cover"], base: response.url, host: source.host),
            desc: values["desc"],
            cat: values["cat"],
            status: values["status"],
            lastChapterTitle: values["lastChapterTitle"],
            updateTime: values["updateTime"],
            detailUrl: url,
            sourceAlias: source.alias,
            sourceName: source.sourceName
        )
    }

    // MARK: - 章节目录（带分页）

    func chapterList(source: XBSSource, url: String) async throws -> [XBSChapter] {
        guard let action = source.action("chapterList") else {
            throw XBSError.actionMissing("chapterList")
        }
        let moreKeys = action.dict("moreKeys") ?? [:]
        let maxPage = moreKeys.int("maxPage") ?? Self.hardMaxPage

        var chapters: [XBSChapter] = []
        var nextURL: String? = url
        var page = 0
        var lastParams: [String: Any] = ["queryInfo": ["url": url, "detailUrl": url]]

        while let current = nextURL, page < min(maxPage, Self.hardMaxPage) {
            page += 1
            var params = lastParams
            params["result"] = current
            params["pageIndex"] = page

            let response = try await fetch(action: action, source: source, params: params)
            let items = try parseList(action: action, response: response, params: params)

            for item in items {
                let values = evaluateFields(action: action, item: item, response: response, params: params,
                                            keys: ["title", "url", "detailUrl"])
                let title = (values["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let link = values["url"] ?? values["detailUrl"] ?? ""
                guard !title.isEmpty, !link.isEmpty else { continue }
                chapters.append(XBSChapter(
                    title: title,
                    url: absoluteURL(link, base: response.url, host: source.host) ?? link
                ))
            }

            // 翻页
            let nextValues = evaluateFields(action: action, item: parseItem(action: action, response: response), response: response,
                                            params: params, keys: ["nextPageUrl"])
            let next = (nextValues["nextPageUrl"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if next.isEmpty {
                nextURL = nil
            } else {
                nextURL = absoluteURL(next, base: response.url, host: source.host)
                lastParams["lastResponse"] = ["nextPageUrl": nextURL ?? ""]
                lastParams["responseUrl"] = response.url
            }
        }
        return chapters
    }

    // MARK: - 章节正文（带分页）

    func chapterContent(source: XBSSource, url: String) async throws -> String {
        guard let action = source.action("chapterContent") else {
            throw XBSError.actionMissing("chapterContent")
        }
        let moreKeys = action.dict("moreKeys") ?? [:]
        let maxPage = moreKeys.int("maxPage") ?? Self.hardMaxPage

        var parts: [String] = []
        var nextURL: String? = url
        var page = 0
        var lastParams: [String: Any] = ["queryInfo": ["url": url, "detailUrl": url]]

        while let current = nextURL, page < min(maxPage, Self.hardMaxPage) {
            page += 1
            var params = lastParams
            params["result"] = current
            params["pageIndex"] = page

            let response = try await fetch(action: action, source: source, params: params)
            let values = evaluateFields(action: action, item: parseItem(action: action, response: response), response: response, params: params,
                                        keys: ["content", "title"], joinMultiline: true)
            let text = values["content"] ?? ""
            if !text.isEmpty {
                parts.append(text)
            }

            let nextValues = evaluateFields(action: action, item: parseItem(action: action, response: response), response: response,
                                            params: params, keys: ["nextPageUrl"])
            let next = (nextValues["nextPageUrl"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if next.isEmpty {
                nextURL = nil
            } else {
                nextURL = absoluteURL(next, base: response.url, host: source.host)
                lastParams["lastResponse"] = ["nextPageUrl": nextURL ?? ""]
                lastParams["responseUrl"] = response.url
            }
        }

        let content = parts.joined(separator: "\n")
        guard !content.isEmpty else { throw XBSError.parseFailed("正文为空") }
        return content
    }

    // MARK: - 请求构建与执行

    struct Response {
        let url: String
        let text: String
        let json: Any?
        let document: XPathDocument?
    }

    private func fetch(action: [String: Any], source: XBSSource, params: [String: Any]) async throws -> Response {
        let requestInfo = action.string("requestInfo") ?? "%@result"
        let built = try buildRequest(action: action, requestInfo: requestInfo, source: source, params: params)
        guard let requestURL = URL(string: built.url) ?? URL(string: source.host), !built.url.isEmpty else {
            throw XBSError.badRequest
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 20
        for (k, v) in built.headers { request.setValue(v, forHTTPHeaderField: k) }
        if built.isPOST {
            request.httpMethod = "POST"
            if let bodyParams = built.bodyParams {
                let body = bodyParams
                    .map { "\($0.key)=\(urlEncode("\($0.value)"))" }
                    .sorted()
                    .joined(separator: "&")
                request.httpBody = body.data(using: .utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        let finalURL = urlResponse.url?.absoluteString ?? built.url

        let format = action.string("responseFormatType") ?? ""
        var json: Any?
        if format == "json" || looksLikeJSON(data) {
            json = try? JSONSerialization.jsonObject(with: data)
        }

        let text: String
        if format == "base64str" {
            let raw = String(data: data, encoding: .utf8) ?? ""
            text = String(data: Data(base64Encoded: raw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? data, encoding: .utf8) ?? raw
        } else {
            text = WebPageDecoder.decode(data)
        }

        let document: XPathDocument?
        if format != "json" && json == nil {
            let doc = XPathDocument(html: text, baseURL: finalURL)
            document = doc.isUsable ? doc : nil
        } else {
            document = nil
        }

        return Response(url: finalURL, text: text, json: json, document: document)
    }

    private func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        let c = Character(UnicodeScalar(first))
        return c == "{" || c == "["
    }

    struct BuiltRequest {
        var url: String
        var isPOST = false
        var headers: [String: String]
        var bodyParams: [String: Any]?
    }

    /// requestInfo → 具体请求（模板 or @js:）
    func buildRequest(action: [String: Any], requestInfo: String, source: XBSSource, params: [String: Any]) throws -> BuiltRequest {
        var headers = source.httpHeaders

        if requestInfo.hasPrefix("@js:") {
            let code = String(requestInfo.dropFirst(4))
            guard let ret = runJS(code, source: source, params: params, result: params["result"]) else {
                throw XBSError.badRequest
            }
            if let s = ret as? String, !s.isEmpty {
                return BuiltRequest(url: absoluteURL(s, base: params.string("responseUrl") ?? "", host: source.host) ?? s,
                                    headers: headers)
            }
            guard let dict = ret as? [String: Any] else { throw XBSError.badRequest }
            var url = dict.string("url") ?? ""
            guard !url.isEmpty else { throw XBSError.badRequest }
            url = absoluteURL(url, base: params.string("responseUrl") ?? "", host: source.host) ?? url
            if let actionHeaders = dict["httpHeaders"] as? [String: Any] {
                for (k, v) in actionHeaders { headers[k] = "\(v)" }
            }
            let isPOST = (dict["POST"] as? Bool) == true || dict.string("POST") == "true"
            var bodyParams = dict["httpParams"] as? [String: Any]
            if isPOST {
                // POST：参数放 body，值里的占位符先替换
                if let hp = bodyParams {
                    bodyParams = hp.mapValues { substitutePlaceholders("\($0)", params: params, encodeValues: false) }
                }
            } else {
                // GET：httpParams 必须拼进 URL 查询串（此前被丢弃，导致搜索空参请求）
                if let hp = bodyParams {
                    url = appendQuery(url, items: hp.mapValues { substitutePlaceholders("\($0)", params: params, encodeValues: true) })
                    bodyParams = nil
                }
            }
            return BuiltRequest(url: url, isPOST: isPOST, headers: headers, bodyParams: bodyParams)
        }

        // 模板占位符替换
        var url = requestInfo
        let keyword = params.string("keyWord") ?? ""
        url = url
            .replacingOccurrences(of: "%@keyWord", with: urlEncode(keyword))
            .replacingOccurrences(of: "%@pageIndex", with: params.string("pageIndex") ?? "1")
            .replacingOccurrences(of: "%@offset", with: params.string("offset") ?? "0")
            .replacingOccurrences(of: "%@filter", with: urlEncode(params.string("filter") ?? ""))
            .replacingOccurrences(of: "%@result", with: params.string("result") ?? "")

        url = absoluteURL(url, base: params.string("responseUrl") ?? "", host: source.host) ?? url

        if let actionHeaders = action["httpHeaders"] as? [String: Any] {
            for (k, v) in actionHeaders { headers[k] = "\(v)" }
        }
        let isPOST = (action["POST"] as? Bool) == true || action.string("POST") == "true"
        var bodyParams = action["httpParams"] as? [String: Any]
        if isPOST {
            if let hp = bodyParams {
                bodyParams = hp.mapValues { substitutePlaceholders("\($0)", params: params, encodeValues: false) }
            }
        } else {
            if let hp = bodyParams {
                url = appendQuery(url, items: hp.mapValues { substitutePlaceholders("\($0)", params: params, encodeValues: true) })
                bodyParams = nil
            }
        }
        return BuiltRequest(url: url, isPOST: isPOST, headers: headers, bodyParams: bodyParams)
    }

    /// 替换参数值中的 %@keyWord 等占位符
    private func substitutePlaceholders(_ text: String, params: [String: Any], encodeValues: Bool) -> String {
        let keyword = params.string("keyWord") ?? ""
        var out = text
            .replacingOccurrences(of: "%@keyWord", with: encodeValues ? urlEncode(keyword) : keyword)
            .replacingOccurrences(of: "%@pageIndex", with: params.string("pageIndex") ?? "1")
            .replacingOccurrences(of: "%@offset", with: params.string("offset") ?? "0")
            .replacingOccurrences(of: "%@filter", with: encodeValues ? urlEncode(params.string("filter") ?? "") : (params.string("filter") ?? ""))
            .replacingOccurrences(of: "%@result", with: params.string("result") ?? "")
        if encodeValues {
            // 已是完整 URL/绝对路径的值不再二次编码
            if out.hasPrefix("http") { out = out.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? out }
        }
        return out
    }

    /// 把字典拼成 URL 查询串（保留已有 query）
    private func appendQuery(_ urlString: String, items: [String: String]) -> String {
        guard !items.isEmpty, var comps = URLComponents(string: urlString) else { return urlString }
        var queryItems = comps.queryItems ?? []
        let existing = Set(queryItems.map { $0.name })
        for (k, v) in items.sorted(by: { $0.key < $1.key }) where !existing.contains(k) {
            queryItems.append(URLQueryItem(name: k, value: v))
        }
        comps.queryItems = queryItems
        return comps.url?.absoluteString ?? urlString
    }

    // MARK: - 列表与字段解析

    private func parseItem(action: [String: Any], response: Response) -> Any? {
        // 详情/正文等非列表动作，解析上下文 = 整个响应
        if let json = response.json { return json }
        if let doc = response.document { return .some(doc) }
        return nil
    }

    private func parseList(action: [String: Any], response: Response, params: [String: Any]) throws -> [Any] {
        guard let listRule = action.string("list"), !listRule.isEmpty else {
            // 无 list：单对象模式（如 JSON 接口直接返回详情/正文）
            if let json = response.json { return [json] }
            if let doc = response.document { return [doc] }
            throw XBSError.parseFailed("缺少 list 规则")
        }

        let segments = splitRuleChain(listRule)
        for segment in segments {
            if segment.hasPrefix("@js:") {
                if let ret = runJS(String(segment.dropFirst(4)), source: nil, params: params, result: jsonResultValue(response)) {
                    if let arr = flattenList(ret) { return arr }
                }
            } else if segment.hasPrefix("$.") {
                guard let json = response.json else { continue }
                if let value = jsonPath(json, segment), let arr = flattenList(value) { return arr }
            } else if let doc = response.document {
                let value = doc.evaluate(segment)
                if case .nodes(let nodes) = value, !nodes.isEmpty {
                    return nodes
                }
            }
        }
        return []
    }

    /// 求值一组字段规则，返回 [字段名: 值]
    func evaluateFields(action: [String: Any], item: Any?, response: Response, params: [String: Any],
                        keys: [String], joinMultiline: Bool = false) -> [String: String] {
        var out: [String: String] = [:]
        let removeHtml = (action.dict("moreKeys")?["removeHtmlKeys"] as? [Any])?.compactMap { "\($0)" } ?? []

        for key in keys {
            guard let rule = action.string(key), !rule.isEmpty else { continue }
            let value = evaluateRule(rule, item: item, response: response, params: params, joinMultiline: joinMultiline)
            var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if removeHtml.contains(key) {
                cleaned = stripHTML(cleaned)
            }
            if !cleaned.isEmpty {
                out[key] = cleaned
            }
        }
        return out
    }

    /// 单条规则求值：支持 `xpath || $.path || @js:` 回退链与 `rule||@js:` 二段处理
    func evaluateRule(_ rule: String, item: Any?, response: Response, params: [String: Any], joinMultiline: Bool = false) -> String {
        let segments = splitRuleChain(rule)
        var current: Any? = item

        for (index, segment) in segments.enumerated() {
            let isLast = index == segments.count - 1
            var value: Any?

            if segment.hasPrefix("@js:") {
                let code = String(segment.dropFirst(4))
                value = runJS(code, source: nil, params: params, result: current ?? jsonResultValue(response))
                current = value
                continue
            }

            if segment.hasPrefix("$.") {
                let target = isLast ? (item ?? response.json) : (current ?? response.json)
                if let json = target {
                    value = jsonPath(json, segment)
                }
            } else if let doc = response.document {
                // 列表项为节点 → 上下文求值；否则整页求值
                let contextNode: UnsafeMutablePointer<xmlNode>? = (item as? UnsafeMutablePointer<xmlNode>) ?? nil
                let result = doc.evaluate(segment, contextNode: contextNode)
                switch result {
                case .nodes(let nodes):
                    if joinMultiline {
                        value = nodes.map { XPathDocument.content(of: $0) }.joined(separator: "\n")
                    } else if let first = nodes.first {
                        value = XPathDocument.content(of: first)
                    }
                case .string(let s):
                    value = s
                }
            } else if let s = current as? String {
                value = s
            }

            if let value, let s = value as? String, !s.isEmpty {
                current = value
                // 回退链：拿到非空值且下一段不是 @js: 二段处理 → 结束
                if isLast || !segments[index + 1].hasPrefix("@js:") {
                    break
                }
            } else if !isLast, segments[index + 1].hasPrefix("@js:") == false {
                // 当前段为空 → 尝试下一段回退
                continue
            } else if let value {
                current = value
            }
        }

        switch current {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    // MARK: - JS 沙盒

    private func runJS(_ code: String, source: XBSSource?, params: [String: Any], result: Any?) -> Any? {
        guard let context = JSContext() else { return nil }

        let configDict: [String: Any] = source.map { source in
            var c = source.config
            c["host"] = source.host
            c["httpHeaders"] = source.httpHeaders
            return c
        } ?? [:]

        let jsConfig = JSValue(object: configDict, in: context) ?? JSValue(undefinedIn: context)
        let jsParams = JSValue(object: params, in: context) ?? JSValue(undefinedIn: context)
        let jsResult: JSValue
        if let result {
            jsResult = JSValue(object: result, in: context) ?? JSValue(undefinedIn: context)
        } else {
            jsResult = JSValue(nullIn: context)
        }

        let wrapped = "function(config, params, result) {\n\(code)\n}"
        guard let function = context.evaluateScript(wrapped), !function.isUndefined else { return nil }

        let ret = function.call(withArguments: [jsConfig, jsParams, jsResult])
        guard let ret, !ret.isUndefined, !ret.isNull else { return nil }
        return ret.toObject()
    }

    // MARK: - 工具

    /// 按 `||` 拆规则链，仅在 || 后跟 @js: / $. / // / 时拆分，避免误切 JS 代码
    private func splitRuleChain(_ rule: String) -> [String] {
        let pattern = "\\|\\|(?=@js:|\\$|//|/)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [rule] }
        let ns = rule as NSString
        var parts: [String] = []
        var last = 0
        regex.enumerateMatches(in: rule, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.range.location > last else { return }
            parts.append(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
            last = match.range.location + match.range.length
        }
        parts.append(ns.substring(from: last))
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func flattenList(_ value: Any) -> [Any]? {
        if let arr = value as? [Any] { return arr }
        return [value]
    }

    /// `$.a.b.0` JSON 路径取值
    private func jsonPath(_ json: Any, _ path: String) -> Any? {
        let components = path.split(separator: ".").map(String.init).filter { $0 != "$" }
        var current = json
        for component in components {
            if let dict = current as? [String: Any] {
                guard let next = dict[component] else { return nil }
                current = next
            } else if let arr = current as? [Any], let index = Int(component), arr.indices.contains(index) {
                current = arr[index]
            } else if let dict = current as? [String: Any] {
                // 特殊键带点的兜底：整键匹配
                guard let next = dict[component] else { return nil }
                current = next
            } else {
                return nil
            }
        }
        return current
    }

    private func jsonResultValue(_ response: Response) -> Any? {
        response.json ?? response.text
    }

    private func stripHTML(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]*>") else { return s }
        var out = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
        out = out
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return out
    }

    func absoluteURL(_ link: String?, base: String?, host: String?) -> String? {
        guard var link, !link.isEmpty else { return nil }
        if link.hasPrefix("http://") || link.hasPrefix("https://") { return link }
        if link.hasPrefix("//") {
            if let host, let scheme = URL(string: host)?.scheme {
                return scheme + ":" + link
            }
            return "https:" + link
        }
        let bases = [base, host].compactMap { $0 }.filter { !$0.isEmpty }
        for b in bases {
            if let baseURL = URL(string: b) {
                let resolved = URL(string: link, relativeTo: baseURL)?.absoluteString
                if let resolved { return resolved }
            }
        }
        return link
    }

    private func urlEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
