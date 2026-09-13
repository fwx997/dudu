//
//  XBSSourceEditView.swift
//  Legado-iOS
//
//  站点编辑器（对齐香色闺阁新建/编辑站点页：基础信息 + 搜索/详情/目录/正文四配置）
//

import SwiftUI

struct XBSSourceEditView: View {
    @ObservedObject var store: XBSSourceStore
    @Environment(\.dismiss) private var dismiss

    let originalAlias: String?

    // 基础信息
    @State private var sourceName = ""
    @State private var host = ""
    @State private var sourceType = "text"
    @State private var weight = "9999"
    @State private var remark = ""

    // 搜索
    @State private var searchRequest = ""
    @State private var searchList = ""
    @State private var searchBookName = ""
    @State private var searchAuthor = ""
    @State private var searchDetailUrl = ""
    @State private var searchCover = ""
    @State private var searchDesc = ""

    // 详情
    @State private var detailRequest = ""
    @State private var detailTitle = ""
    @State private var detailCover = ""
    @State private var detailDesc = ""
    @State private var detailAuthor = ""

    // 目录
    @State private var tocRequest = ""
    @State private var tocList = ""
    @State private var tocTitle = ""
    @State private var tocUrl = ""

    // 正文
    @State private var contentRequest = ""
    @State private var contentRule = ""
    @State private var contentNextPage = ""

    private let typeOptions: [(String, String)] = [
        ("文本/小说", "text"), ("图片/漫画", "image"), ("音频/听书", "audio"), ("视频", "video"),
    ]

    init(store: XBSSourceStore, source: XBSSource?) {
        self.store = store
        self.originalAlias = source?.alias
        if let cfg = source?.config {
            _sourceName = State(initialValue: cfg.string("sourceName") ?? "")
            _host = State(initialValue: cfg.string("host") ?? cfg.string("sourceUrl") ?? "")
            _sourceType = State(initialValue: cfg.string("sourceType") ?? "text")
            _weight = State(initialValue: cfg.string("weight") ?? "9999")
            _remark = State(initialValue: cfg.string("bookSourceComment") ?? "")

            let sb = cfg.dict("searchBook") ?? [:]
            _searchRequest = State(initialValue: sb.string("requestInfo") ?? "")
            _searchList = State(initialValue: sb.string("list") ?? "")
            _searchBookName = State(initialValue: sb.string("bookName") ?? "")
            _searchAuthor = State(initialValue: sb.string("author") ?? "")
            _searchDetailUrl = State(initialValue: sb.string("detailUrl") ?? sb.string("url") ?? "")
            _searchCover = State(initialValue: sb.string("cover") ?? "")
            _searchDesc = State(initialValue: sb.string("desc") ?? "")

            let bd = cfg.dict("bookDetail") ?? [:]
            _detailRequest = State(initialValue: bd.string("requestInfo") ?? "")
            _detailTitle = State(initialValue: bd.string("title") ?? "")
            _detailCover = State(initialValue: bd.string("cover") ?? "")
            _detailDesc = State(initialValue: bd.string("desc") ?? "")
            _detailAuthor = State(initialValue: bd.string("author") ?? "")

            let cl = cfg.dict("chapterList") ?? [:]
            _tocRequest = State(initialValue: cl.string("requestInfo") ?? "")
            _tocList = State(initialValue: cl.string("list") ?? "")
            _tocTitle = State(initialValue: cl.string("title") ?? "")
            _tocUrl = State(initialValue: cl.string("url") ?? cl.string("detailUrl") ?? "")

            let cc = cfg.dict("chapterContent") ?? [:]
            _contentRequest = State(initialValue: cc.string("requestInfo") ?? "")
            _contentRule = State(initialValue: cc.string("content") ?? "")
            _contentNextPage = State(initialValue: cc.string("nextPageUrl") ?? "")
        }
    }

    var body: some View {
        Form {
            Section("基础信息") {
                TextField("站点名", text: $sourceName)
                TextField("host，如 https://www.example.com", text: $host)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                Picker("类型", selection: $sourceType) {
                    ForEach(typeOptions, id: \.1) { t in
                        Text(t.0).tag(t.1)
                    }
                }
                TextField("权重（越大越优先，1-9999）", text: $weight)
                    .keyboardType(.numberPad)
                TextField("备注（可选）", text: $remark)
            }

            actionSection("书籍搜索", request: $searchRequest, list: $searchList,
                          fields: [("书名", $searchBookName), ("作者", $searchAuthor),
                                   ("详情链接", $searchDetailUrl), ("封面", $searchCover), ("简介", $searchDesc)])

            actionSection("书籍详情", request: $detailRequest, list: .constant(""),
                          fields: [("书名", $detailTitle), ("作者", $detailAuthor),
                                   ("封面", $detailCover), ("简介", $detailDesc)])

            actionSection("章节列表", request: $tocRequest, list: $tocList,
                          fields: [("章节标题", $tocTitle), ("章节链接", $tocUrl)])

            actionSection("章节内容", request: $contentRequest, list: .constant(""),
                          fields: [("正文内容", $contentRule), ("下一页链接", $contentNextPage)])
        }
        .navigationTitle(originalAlias == nil ? "新建站点" : "编辑站点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(sourceName.isEmpty || host.isEmpty)
            }
        }
    }

    private func actionSection(_ title: String, request: Binding<String>, list: Binding<String>,
                               fields: [(String, Binding<String>)]) -> some View {
        Section(header: Text(title)) {
            TextEditor(text: request)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: request.wrappedValue.hasPrefix("@js:") ? 90 : 40)
                .autocapitalization(.none)
            if !list.wrappedValue.isEmpty || title == "书籍搜索" || title == "章节列表" {
                TextField("列表 XPath", text: list)
                    .font(.system(.caption, design: .monospaced))
                    .autocapitalization(.none)
            }
            ForEach(fields, id: \.0) { field in
                TextField(field.0 + " 规则", text: field.1)
                    .font(.system(.caption, design: .monospaced))
                    .autocapitalization(.none)
            }
        }
    }

    // MARK: - 保存

    private func save() {
        var cfg: [String: Any] = originalAlias.flatMap { store.source(alias: $0) }?.config ?? [:]
        cfg["sourceName"] = sourceName
        cfg["sourceUrl"] = host
        cfg["host"] = host
        cfg["sourceType"] = sourceType
        cfg["weight"] = weight.isEmpty ? "9999" : weight
        cfg["enable"] = 1
        cfg["miniAppVersion"] = cfg["miniAppVersion"] ?? "2.56.1"
        cfg["lastModifyTime"] = String(Int(Date().timeIntervalSince1970))
        if !remark.isEmpty { cfg["bookSourceComment"] = remark }

        func buildAction(_ existing: [String: Any]?, request: String, list: String,
                         fields: [(String, String)]) -> [String: Any]? {
            var a = existing ?? ["actionID": "", "parserID": "DOM"]
            if !request.isEmpty { a["requestInfo"] = request }
            if !list.isEmpty { a["list"] = list }
            for (key, value) in fields where !value.isEmpty {
                a[key] = value
            }
            let actionID: String = {
                switch title01 {
                default: return ""
                }
            }()
            _ = actionID
            return a
        }
        _ = buildAction

        // 搜索
        if !searchRequest.isEmpty {
            var a = cfg.dict("searchBook") ?? [:]
            a["actionID"] = "searchBook"
            a["parserID"] = a["parserID"] ?? "DOM"
            a["requestInfo"] = searchRequest
            if !searchList.isEmpty { a["list"] = searchList }
            if !searchBookName.isEmpty { a["bookName"] = searchBookName }
            if !searchAuthor.isEmpty { a["author"] = searchAuthor }
            if !searchDetailUrl.isEmpty { a["detailUrl"] = searchDetailUrl }
            if !searchCover.isEmpty { a["cover"] = searchCover }
            if !searchDesc.isEmpty { a["desc"] = searchDesc }
            cfg["searchBook"] = a
        }
        // 详情
        if !detailRequest.isEmpty || !detailTitle.isEmpty {
            var a = cfg.dict("bookDetail") ?? [:]
            a["actionID"] = "bookDetail"
            a["parserID"] = a["parserID"] ?? "DOM"
            if !detailRequest.isEmpty { a["requestInfo"] = detailRequest }
            if !detailTitle.isEmpty { a["title"] = detailTitle }
            if !detailAuthor.isEmpty { a["author"] = detailAuthor }
            if !detailCover.isEmpty { a["cover"] = detailCover }
            if !detailDesc.isEmpty { a["desc"] = detailDesc }
            cfg["bookDetail"] = a
        }
        // 目录
        if !tocRequest.isEmpty || !tocList.isEmpty {
            var a = cfg.dict("chapterList") ?? [:]
            a["actionID"] = "chapterList"
            a["parserID"] = a["parserID"] ?? "DOM"
            if !tocRequest.isEmpty { a["requestInfo"] = tocRequest }
            if !tocList.isEmpty { a["list"] = tocList }
            if !tocTitle.isEmpty { a["title"] = tocTitle }
            if !tocUrl.isEmpty { a["url"] = tocUrl }
            cfg["chapterList"] = a
        }
        // 正文
        if !contentRequest.isEmpty || !contentRule.isEmpty {
            var a = cfg.dict("chapterContent") ?? [:]
            a["actionID"] = "chapterContent"
            a["parserID"] = a["parserID"] ?? "DOM"
            if !contentRequest.isEmpty { a["requestInfo"] = contentRequest }
            if !contentRule.isEmpty { a["content"] = contentRule }
            if !contentNextPage.isEmpty { a["nextPageUrl"] = contentNextPage }
            cfg["chapterContent"] = a
        }

        let alias = originalAlias ?? sourceName
        store.importSources([XBSSource(alias: alias, config: cfg)])
        dismiss()
    }
}

private let title01 = ""
