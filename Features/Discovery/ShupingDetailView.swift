//
//  ShupingDetailView.swift
//  Legado-iOS
//
//  书评详情（对齐 ShupingView）：站内渲染正文 + 可点击链接
//

import SwiftUI

struct ShupingDetailView: View {
    let shuping: XBSEngine.XBSShuping

    @State private var isLoading = true
    @State private var bodyText = ""
    @State private var links: [ShupingLink] = []
    @State private var errorMessage: String?

    struct ShupingLink: Identifiable {
        let text: String
        let url: URL
        var id: String { url.absoluteString + text }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(shuping.title)
                    .font(.title3.bold())

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Text(bodyText)
                        .font(.callout)
                        .lineSpacing(6)
                }

                if !links.isEmpty {
                    Divider()
                    Text("相关链接")
                        .font(.headline)
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            Text(link.text.isEmpty ? link.url.absoluteString : link.text)
                                .font(.callout)
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("书评")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let url = URL(string: shuping.detailUrl) else {
            errorMessage = "链接无效"
            isLoading = false
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = WebPageDecoder.decode(data)
            bodyText = Self.extractText(from: html)
            links = Self.extractLinks(from: html, baseURL: url)
            if bodyText.isEmpty && links.isEmpty {
                errorMessage = "正文解析失败"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    static func extractText(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<br\\s*/?>|</p>|</div>|</h[1-6]>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n\n")
    }

    static func extractLinks(from html: String, baseURL: URL) -> [ShupingLink] {
        guard let regex = try? NSRegularExpression(
            pattern: "(?is)<a[^>]+href=[\"']([^\"'#]+)[\"'][^>]*>(.*?)</a>",
            options: []) else { return [] }
        let ns = html as NSString
        var seen = Set<String>()
        var result: [ShupingLink] = []
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let rawHref = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let label = extractText(from: ns.substring(with: m.range(at: 2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let href = URL(string: rawHref, relativeTo: baseURL)?.absoluteURL,
                  !seen.contains(href.absoluteString) else { continue }
            seen.insert(href.absoluteString)
            result.append(ShupingLink(text: String(label.prefix(40)), url: href))
            if result.count >= 20 { break }
        }
        return result
    }

    static func decodeEntities(_ text: String) -> String {
        var t = text
        let map = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                   "&#39;": "'", "&apos;": "'", "&amp;": "&"]
        for (entity, char) in map {
            t = t.replacingOccurrences(of: entity, with: char)
        }
        return t
    }
}
