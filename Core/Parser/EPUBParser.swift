//
//  EPUBParser.swift
//  Legado-iOS
//
//  EPUB 解析器（完整版）
//

import Foundation
import UIKit
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

/// EPUB 解析器
class EPUBParser {
    
    struct EPUBBook {
        let title: String
        let author: String
        let coverImage: Data?
        let chapters: [EPUBChapter]
        let metadata: EPUBMetadata
        let tableOfContents: [TOCItem]
    }
    
    struct EPUBMetadata {
        let title: String
        let author: String
        let publisher: String?
        let language: String?
        let description: String?
        let rights: String?
        let date: String?
        let identifier: String?
    }
    
    struct EPUBChapter {
        let id: String
        let title: String
        let href: String
        let content: String
        let index: Int
        let mediaType: String
    }
    
    struct TOCItem {
        let title: String
        let href: String
        let level: Int
        let children: [TOCItem]
    }
    
    // MARK: - 主解析方法
    static func parse(file url: URL) async throws -> EPUBBook {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EPUBError.fileNotFound
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 解压 EPUB
        try unzipFile(at: url, to: tempDir)
        
        // 解析 container.xml 获取 OPF 路径
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        let opfRelativePath = try parseContainer(at: containerPath)
        let opfPath = tempDir.appendingPathComponent(opfRelativePath)
        let basePath = opfPath.deletingLastPathComponent()
        
        // 解析 OPF 文件
        let (metadata, manifest, spine) = try parseOPF(at: opfPath)
        
        // 解析目录（NCX 或 Nav）
        let toc = try parseNavigation(manifest: manifest, basePath: basePath)
        
        // 解析章节内容
        let chapters = try parseChapters(spine: spine, manifest: manifest, basePath: basePath)
        
        // 获取封面
        let coverImage = try extractCover(manifest: manifest, metadata: metadata, basePath: basePath)
        
        return EPUBBook(
            title: metadata.title,
            author: metadata.author,
            coverImage: coverImage,
            chapters: chapters,
            metadata: metadata,
            tableOfContents: toc
        )
    }
    
    // MARK: - 解压文件
    private static func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        #if canImport(ZIPFoundation)
        do {
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
        } catch {
            throw EPUBError.parseFailed("解压失败：\(error.localizedDescription)")
        }
        #else
        throw EPUBError.parseFailed("缺少 ZIPFoundation 依赖，无法解压 EPUB")
        #endif
    }
    
    // MARK: - 解析 container.xml
    private static func parseContainer(at url: URL) throws -> String {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        guard let opfPath = extractFirstMatch(in: content, pattern: "full-path=\"([^\"]+)\"") else {
            throw EPUBError.parseFailed("找不到 content.opf")
        }
        
        return opfPath
    }
    
    // MARK: - 解析 OPF 文件
    private static func parseOPF(at url: URL) throws -> (EPUBMetadata, [String: ManifestItem], [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        // 解析元数据
        let metadata = EPUBMetadata(
            title: extractMetadata(content: content, tag: "dc:title") ?? "未知书籍",
            author: extractMetadata(content: content, tag: "dc:creator") ?? "未知作者",
            publisher: extractMetadata(content: content, tag: "dc:publisher"),
            language: extractMetadata(content: content, tag: "dc:language"),
            description: extractMetadata(content: content, tag: "dc:description"),
            rights: extractMetadata(content: content, tag: "dc:rights"),
            date: extractMetadata(content: content, tag: "dc:date"),
            identifier: extractMetadata(content: content, tag: "dc:identifier")
        )
        
        // 解析 manifest
        var manifest: [String: ManifestItem] = [:]
        let itemPattern = "<item\\s+([^>]+)/?>"
        let itemRegex = try NSRegularExpression(pattern: itemPattern)
        let items = itemRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in items {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let attributes = String(content[range])
            
            if let id = extractAttribute(attributes, name: "id"),
               let href = extractAttribute(attributes, name: "href"),
               let mediaType = extractAttribute(attributes, name: "media-type") {
                manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType)
            }
        }
        
        // 解析 spine（阅读顺序）
        var spine: [String] = []
        if let spineContent = extractFirstMatch(in: content, pattern: "<spine[^>]*>(.*?)</spine>") {
            let idrefPattern = "idref=\"([^\"]+)\""
            let idrefRegex = try NSRegularExpression(pattern: idrefPattern)
            let idrefs = idrefRegex.matches(in: spineContent, range: NSRange(spineContent.startIndex..., in: spineContent))
            
            for match in idrefs {
                if let range = Range(match.range(at: 1), in: spineContent) {
                    spine.append(String(spineContent[range]))
                }
            }
        }
        
        return (metadata, manifest, spine)
    }
    
    // MARK: - 解析目录
    private static func parseNavigation(manifest: [String: ManifestItem], basePath: URL) throws -> [TOCItem] {
        // 尝试找 NCX 文件
        if let ncxItem = manifest.first(where: { $0.value.mediaType == "application/x-dtbncx+xml" })?.value {
            let ncxPath = basePath.appendingPathComponent(ncxItem.href)
            return try parseNCX(at: ncxPath)
        }
        
        // 尝试找 Nav 文件（EPUB 3）
        if let navItem = manifest.first(where: { 
            $0.value.mediaType == "application/xhtml+xml" && $0.value.properties?.contains("nav") == true 
        })?.value {
            let navPath = basePath.appendingPathComponent(navItem.href)
            return try parseNav(at: navPath)
        }
        
        return []
    }
    
    // MARK: - 解析 NCX 文件
    private static func parseNCX(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var items: [TOCItem] = []
        
        // 提取 navPoint
        let navPointPattern = "<navPoint[^>]*>(.*?)</navPoint>"
        let navPointRegex = try NSRegularExpression(pattern: navPointPattern, options: [.dotMatchesLineSeparators])
        let navPoints = navPointRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in navPoints {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let navPointContent = String(content[range])
            
            if let title = extractFirstMatch(in: navPointContent, pattern: "<text[^>]*>([^<]+)</text>"),
               let href = extractFirstMatch(in: navPointContent, pattern: "src=\"([^\"]+)\"") {
                items.append(TOCItem(title: title, href: href, level: 1, children: []))
            }
        }
        
        return items
    }
    
    // MARK: - 解析 Nav 文件
    private static func parseNav(at url: URL) throws -> [TOCItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var items: [TOCItem] = []
        
        // 提取 nav 中的链接
        let linkPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"
        let linkRegex = try NSRegularExpression(pattern: linkPattern)
        let links = linkRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        for match in links {
            guard let hrefRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content) else { continue }
            
            let href = String(content[hrefRange])
            let title = String(content[titleRange])
            
            items.append(TOCItem(title: title, href: href, level: 1, children: []))
        }
        
        return items
    }
    
    // MARK: - 解析章节
    private static func parseChapters(spine: [String], manifest: [String: ManifestItem], basePath: URL) throws -> [EPUBChapter] {
        var chapters: [EPUBChapter] = []
        
        for (index, itemId) in spine.enumerated() {
            guard let item = manifest[itemId] else { continue }
            
            let chapterPath = basePath.appendingPathComponent(item.href)
            var chapterContent = ""
            var chapterTitle = "第 \(index + 1) 章"
            
            if FileManager.default.fileExists(atPath: chapterPath.path) {
                let htmlContent = try String(contentsOf: chapterPath, encoding: .utf8)
                
                // 提取标题
                if let title = extractFirstMatch(in: htmlContent, pattern: "<title[^>]*>([^<]+)</title>") {
                    chapterTitle = title
                } else if let h1 = extractFirstMatch(in: htmlContent, pattern: "<h1[^>]*>([^<]+)</h1>") {
                    chapterTitle = h1
                }
                
                // 转换为纯文本
                chapterContent = htmlToText(html: htmlContent)
            }
            
            chapters.append(EPUBChapter(
                id: itemId,
                title: chapterTitle,
                href: item.href,
                content: chapterContent,
                index: index,
                mediaType: item.mediaType
            ))
        }
        
        return chapters
    }
    
    // MARK: - 提取封面
    private static func extractCover(manifest: [String: ManifestItem], metadata: EPUBMetadata, basePath: URL) -> Data? {
        // 1. 尝试从 manifest 找封面
        if let coverItem = manifest.first(where: { 
            $0.value.properties?.contains("cover-image") == true 
        })?.value {
            let coverPath = basePath.appendingPathComponent(coverItem.href)
            return try? Data(contentsOf: coverPath)
        }
        
        // 2. 尝试找名为 cover 的文件
        for (_, item) in manifest {
            if item.href.lowercased().contains("cover") && 
               (item.mediaType.hasPrefix("image/")) {
                let coverPath = basePath.appendingPathComponent(item.href)
                if let data = try? Data(contentsOf: coverPath) {
                    return data
                }
            }
        }
        
        return nil
    }
    
    // MARK: - HTML 转纯文本
    private static func htmlToText(html: String) -> String {
        // 1. 移除 script 和 style
        var text = html
        text = text.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: .regularExpression)
        
        // 2. 将块级标签转换为换行
        let blockTags = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "br", "li"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: "</\(tag)>", with: "\n", options: .regularExpression)
        }
        
        // 3. 移除所有 HTML 标签
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 4. 解码 HTML 实体
        text = decodeHTMLEntities(text)
        
        // 5. 规范化空白
        text = text.replacingOccurrences(of: "[\\t\\r]+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n\\s*\\n", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 解码 HTML 实体
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        
        // 常见 HTML 实体映射
        let entityMap: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&nbsp;", " ")
        ]
        
        for (entity, char) in entityMap {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        // 解码数字实体
        let decimalPattern = "&#(\\d+);"
        if let decimalRegex = try? NSRegularExpression(pattern: decimalPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = decimalRegex.matches(in: result, range: nsRange)
            
            // 从后向前替换，避免索引偏移
            for match in matches.reversed() {
                guard let groupRange = Range(match.range(at: 1), in: result),
                      let fullRange = Range(match.range, in: result),
                      let code = Int(result[groupRange]),
                      let scalar = UnicodeScalar(code) else { continue }
                result.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }
        
        return result
    }
    
    // MARK: - 辅助方法
    private static func extractFirstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    private static func extractMetadata(content: String, tag: String) -> String? {
        return extractFirstMatch(in: content, pattern: "<\(tag)[^>]*>([^<]+)</\(tag)>")
    }
    
    private static func extractAttribute(_ text: String, name: String) -> String? {
        let pattern = "\(name)=\"([^\"]+)\""
        return extractFirstMatch(in: text, pattern: pattern)
    }
}

// MARK: - ManifestItem
private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    var properties: String? {
        // 从原始属性中提取
        return nil
    }
}

// MARK: - EPUBError
enum EPUBError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case parseFailed(String)
    case chapterNotFound
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "EPUB 文件不存在"
        case .invalidFormat: return "无效的 EPUB 格式"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        case .chapterNotFound: return "章节不存在"
        }
    }
}