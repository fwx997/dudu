//
//  BuiltInBrowserView.swift
//  Legado-iOS
//
//  内置浏览器 - 支持源站登录和 Cookie 管理
//

import SwiftUI
import WebKit

/// 内置浏览器视图
struct BuiltInBrowserView: View {
    let initialURL: URL?
    let source: BookSource?
    let onCookiesSaved: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BrowserViewModel
    
    init(
        url: URL? = nil,
        source: BookSource? = nil,
        onCookiesSaved: ((String) -> Void)? = nil
    ) {
        self.initialURL = url
        self.source = source
        self.onCookiesSaved = onCookiesSaved
        
        _viewModel = StateObject(wrappedValue: BrowserViewModel(
            initialURL: url,
            source: source
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 地址栏
                addressBar
                
                // 进度条
                if viewModel.isLoading {
                    ProgressView(value: viewModel.loadingProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                
                // WebView
                WebViewRepresentable(
                    viewModel: viewModel,
                    onLoadComplete: { html, url in
                        viewModel.currentHTML = html
                        viewModel.currentURL = url
                    }
                )
                
                // 工具栏
                toolbar
            }
            .navigationTitle("浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.saveCookiesToSource() }) {
                            Label("保存 Cookie 到书源", systemImage: "cookie")
                        }
                        
                        Button(action: { viewModel.copyCurrentURL() }) {
                            Label("复制当前 URL", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: { viewModel.showJavaScriptAlert = true }) {
                            Label("执行 JavaScript", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        
                        Button(action: { viewModel.clearCookies() }) {
                            Label("清除 Cookie", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Button(action: { viewModel.showSourceView = true }) {
                            Label("查看网页源码", systemImage: "text.alignleft")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("执行 JavaScript", isPresented: $viewModel.showJavaScriptAlert) {
                TextField("输入 JavaScript 代码", text: $viewModel.javaScriptCode, axis: .vertical)
                Button("取消", role: .cancel) {}
                Button("执行") {
                    viewModel.executeJavaScript(viewModel.javaScriptCode)
                }
            }
            .sheet(isPresented: $viewModel.showSourceView) {
                if let html = viewModel.currentHTML {
                    NavigationStack {
                        ScrollView {
                            Text(html)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                        }
                        .navigationTitle("网页源码")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("关闭") {
                                    viewModel.showSourceView = false
                                }
                            }
                        }
                    }
                }
            }
            .onReceive(viewModel.cookiesSaved) { cookieString in
                onCookiesSaved?(cookieString)
            }
        }
    }
    
    // MARK: - 地址栏
    
    private var addressBar: some View {
        HStack(spacing: 8) {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "chevron.left")
                    .disabled(!viewModel.canGoBack)
            }
            .disabled(!viewModel.canGoBack)
            
            Button(action: { viewModel.goForward() }) {
                Image(systemName: "chevron.right")
                    .disabled(!viewModel.canGoForward)
            }
            .disabled(!viewModel.canGoForward)
            
            TextField("输入网址", text: $viewModel.urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.loadURL(viewModel.urlText)
                }
            
            Button(action: { viewModel.loadURL(viewModel.urlText) }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - 工具栏
    
    private var toolbar: some View {
        HStack(spacing: 0) {
            ToolbarButton(title: "后退", icon: "chevron.left") {
                viewModel.goBack()
            }
            .disabled(!viewModel.canGoBack)
            
            ToolbarButton(title: "前进", icon: "chevron.right") {
                viewModel.goForward()
            }
            .disabled(!viewModel.canGoForward)
            
            ToolbarButton(title: "刷新", icon: "arrow.clockwise") {
                viewModel.reload()
            }
            
            ToolbarButton(title: "Cookie", icon: "cookie") {
                viewModel.saveCookiesToSource()
            }
            
            ToolbarButton(title: "分享", icon: "square.and.arrow.up") {
                viewModel.shareCurrentPage()
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
    }
}

// MARK: - 工具栏按钮

struct ToolbarButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WebView Representable

struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    let onLoadComplete: (String, String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // 设置自定义 User-Agent
        if let userAgent = viewModel.source?.userAgent, !userAgent.isEmpty {
            webView.customUserAgent = userAgent
        }
        
        viewModel.webView = webView
        
        // 加载初始 URL
        if let url = viewModel.initialURL {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 不在此处更新，由 ViewModel 控制
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = true
                self.parent.viewModel.loadingProgress = 0
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
                self.parent.viewModel.loadingProgress = 1
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
                self.parent.viewModel.urlText = webView.url?.absoluteString ?? ""
            }
            
            // 获取 HTML
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
                if let html = result as? String {
                    let url = webView.url?.absoluteString ?? ""
                    self.parent.onLoadComplete(html, url)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}

// MARK: - Browser ViewModel

@MainActor
class BrowserViewModel: ObservableObject {
    let initialURL: URL?
    let source: BookSource?
    
    @Published var urlText: String = ""
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var currentHTML: String?
    @Published var currentURL: String = ""
    @Published var showJavaScriptAlert: Bool = false
    @Published var showSourceView: Bool = false
    @Published var javaScriptCode: String = ""
    
    var webView: WKWebView?
    
    let cookiesSaved = PassthroughSubject<String, Never>()
    
    init(initialURL: URL?, source: BookSource?) {
        self.initialURL = initialURL
        self.source = source
        
        if let url = initialURL {
            self.urlText = url.absoluteString
        }
    }
    
    // MARK: - 导航操作
    
    func loadURL(_ urlString: String) {
        var text = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            text = "https://" + text
        }
        
        guard let url = URL(string: text) else { return }
        urlText = text
        webView?.load(URLRequest(url: url))
    }
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        webView?.reload()
    }
    
    // MARK: - Cookie 管理
    
    func saveCookiesToSource() {
        guard let webView = webView else { return }
        
        let dataStore = webView.configuration.websiteDataStore
        dataStore.httpCookieStore.getAllCookies { cookies in
            let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            
            // 保存到书源
            if let source = self.source {
                // 更新书源的 header 或 variable
                // 这里可以通过回调传递给调用者
            }
            
            // 复制到剪贴板
            UIPasteboard.general.string = cookieString
            
            // 发送通知
            self.cookiesSaved.send(cookieString)
            
            // 显示提示
            // Toast.show("Cookie 已保存并复制到剪贴板")
        }
    }
    
    func clearCookies() {
        let dataStore = WKWebsiteDataStore.default()
        let types = Set([WKWebsiteDataTypeCookies])
        
        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {
                // Toast.show("Cookie 已清除")
            }
        }
    }
    
    // MARK: - JavaScript
    
    func executeJavaScript(_ code: String) {
        webView?.evaluateJavaScript(code) { result, error in
            if let error = error {
                print("JavaScript 错误: \(error)")
            } else if let result = result {
                print("JavaScript 结果: \(result)")
            }
        }
    }
    
    // MARK: - 其他操作
    
    func copyCurrentURL() {
        UIPasteboard.general.string = currentURL
        // Toast.show("URL 已复制")
    }
    
    func shareCurrentPage() {
        guard let url = URL(string: currentURL) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - 使用示例

extension BuiltInBrowserView {
    /// 打开书源登录页面
    static func openForLogin(source: BookSource, onLoginSuccess: @escaping (String) -> Void) -> some View {
        let loginURL = source.loginUrl.isEmpty ? source.bookSourceUrl : source.loginUrl
        let url = URL(string: loginURL)
        
        return BuiltInBrowserView(url: url, source: source, onCookiesSaved: onLoginSuccess)
    }
}

import Combine