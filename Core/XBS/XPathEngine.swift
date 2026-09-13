//
//  XPathEngine.swift
//  Legado-iOS
//
//  基于 libxml2 的 HTML XPath 求值器（香色闺阁书源 DOM 规则解析）
//  语义对齐香色闺阁：字段规则里的 `//` 按「当前上下文节点的后代」处理，
//  文档级求值时等价于全局搜索；绝对路径（`/html/...`）按文档根求值。
//

import Foundation
import CoreFoundation
import libxml2

/// XPath 求值结果
enum XPathValue {
    case nodes([UnsafeMutablePointer<xmlNode>])
    case string(String)

    var stringValue: String {
        switch self {
        case .nodes(let nodes):
            guard let first = nodes.first else { return "" }
            return XPathDocument.content(of: first)
        case .string(let s):
            return s
        }
    }

    var isEmpty: Bool {
        switch self {
        case .nodes(let nodes): return nodes.isEmpty
        case .string(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// HTML 文档 + XPath 上下文（持有 libxml2 文档生命周期）
final class XPathDocument {
    private let doc: UnsafeMutablePointer<xmlDoc>?
    private let context: UnsafeMutablePointer<xmlXPathContext>?

    init(html: String, baseURL: String?) {
        let bytes = Array(html.utf8)
        let options = Int32(HTML_PARSE_RECOVER.rawValue | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue)
        doc = bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            return base.withMemoryRebound(to: CChar.self, capacity: buf.count) { cbase in
                htmlReadMemory(cbase, Int32(buf.count), baseURL, "utf-8", options)
            }
        }
        context = doc.map { xmlXPathNewContext($0) }
    }

    var isUsable: Bool { doc != nil && context != nil }

    deinit {
        if let context { xmlXPathFreeContext(context) }
        if let doc { xmlFreeDoc(doc) }
    }

    /// 求值。contextNode 为 nil 时以文档根为上下文。
    func evaluate(_ expression: String, contextNode: UnsafeMutablePointer<xmlNode>? = nil) -> XPathValue {
        guard let context else { return .string("") }

        let xpath = XPathDocument.normalized(expression)
        context.pointee.node = contextNode ?? xmlDocGetRootElement(doc)

        guard let result = xmlXPathEvalExpression(xpath, context) else { return .string("") }
        defer { xmlXPathFreeObject(result) }

        switch result.pointee.type {
        case XPATH_NODESET:
            var nodes: [UnsafeMutablePointer<xmlNode>] = []
            if let nodeset = result.pointee.nodesetval {
                for i in 0..<Int(nodeset.pointee.nodeNr) {
                    if let node = nodeset.pointee.nodeTab[i] {
                        nodes.append(node)
                    }
                }
            }
            return .nodes(nodes)
        case XPATH_BOOLEAN:
            return .string(result.pointee.boolval != 0 ? "true" : "")
        case XPATH_NUMBER:
            let n = result.pointee.floatval
            return .string(n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : "\(n)")
        default:
            if let cstr = result.pointee.stringval {
                return .string(Self.stringFromXmlChar(cstr))
            }
            return .string("")
        }
    }

    /// 香色闺阁语义归一：`//xxx` → `.//xxx`（上下文内后代搜索）
    static func normalized(_ expr: String) -> String {
        let e = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.hasPrefix("//") {
            return "." + e
        }
        return e
    }

    /// 节点字符串内容（text / attr value）
    static func content(of node: UnsafeMutablePointer<xmlNode>) -> String {
        guard let cstr = xmlNodeGetContent(node) else { return "" }
        defer { xmlFree(cstr) }
        return stringFromXmlChar(cstr)
    }

    /// 节点属性值
    static func attribute(_ name: String, of node: UnsafeMutablePointer<xmlNode>) -> String? {
        name.withCString { cName -> String? in
            let prop: String? = cName.withMemoryRebound(to: xmlChar.self, capacity: name.utf8.count + 1) { xmlName in
                guard let cstr = xmlGetProp(node, xmlName) else { return nil }
                defer { xmlFree(cstr) }
                return stringFromXmlChar(cstr)
            }
            return prop
        }
    }

    private static func stringFromXmlChar(_ cstr: UnsafePointer<xmlChar>) -> String {
        cstr.withMemoryRebound(to: CChar.self, capacity: strlen(cstr) + 1) { cchars in
            String(cString: cchars)
        }
    }
}

/// 网页编码探测 + 解码（香色书源常见 GBK/GB2312 站点）
enum WebPageDecoder {
    /// 从 HTML 字节中探测 charset 并解码为 UTF-8 字符串
    static func decode(_ data: Data) -> String {
        let head = String(data: data.prefix(2048), encoding: .utf8) ?? ""
        let lower = head.lowercased()
        var charset = ""
        if let range = lower.range(of: "charset=") {
            let rest = lower[range.upperBound...].prefix(40)
            let m = rest.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            charset = String(m)
        }
        charset = charset.trimmingCharacters(in: CharacterSet(charactersIn: "'\" /"))

        if isGBFamily(charset) {
            let cfEnc = CFStringEncodings.GB_18030_2000.rawValue
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEnc))
            if let s = String(data: data, encoding: String.Encoding(rawValue: nsEnc)) {
                return s
            }
        }
        if charset == "big5" {
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))
            if let s = String(data: data, encoding: String.Encoding(rawValue: nsEnc)) {
                return s
            }
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private static func isGBFamily(_ charset: String) -> Bool {
        let c = charset.lowercased()
        return c.hasPrefix("gb")
    }
}
