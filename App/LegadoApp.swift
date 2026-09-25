//
//  LegadoApp.swift
//  Legado-iOS
//
//  应用入口
//

import SwiftUI

@main
struct LegadoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var importMessage: String?
    @State private var showingImportAlert = false
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    handleURL(url)
                }
                .alert("导入结果", isPresented: $showingImportAlert) {
                    Button("确定", role: .cancel) { importMessage = nil }
                } message: {
                    Text(importMessage ?? "未知结果")
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        if url.scheme == "legado" {
            URLSchemeHandler.handle(url) { result in
                switch result {
                case .success(let message):
                    importMessage = message
                    showingImportAlert = true
                case .failure(let error):
                    importMessage = "导入失败：\(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
        } else if url.isFileURL {
            handleFileImport(url)
        }
    }
    
    private func handleFileImport(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "xbs", "json":
            Task { await importSourceFile(url) }
        case "txt", "epub":
            NotificationCenter.default.post(name: .importLocalBookNotification, object: url)
        default:
            importMessage = "不支持的文件格式：.\(ext)"
            showingImportAlert = true
        }
    }
    @MainActor
    private func importSourceFile(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            if let sources = try? XBSSourceFile.parse(data: data) {
                let added = XBSSourceStore.shared.importSources(sources)
                importMessage = "导入成功：共 \(sources.count) 个站点，新增 \(added) 个"
            } else if url.pathExtension.lowercased() == "json", let text = String(data: data, encoding: .utf8) {
                URLSchemeHandler.importBookSourceJSON(text) { result in
                    switch result {
                    case .success(let message): importMessage = message
                    case .failure(let error): importMessage = "导入失败：\(error.localizedDescription)"
                    }
                }
            } else {
                importMessage = "无法识别此站点文件"
            }
        } catch {
            importMessage = "导入失败：\(error.localizedDescription)"
        }
        showingImportAlert = true
    }

}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = CoreDataStack.shared
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        NotificationCenter.default.post(name: .openURLNotification, object: url)
        return true
    }
}

extension Notification.Name {
    static let openURLNotification = Notification.Name("openURLNotification")
    static let importLocalBookNotification = Notification.Name("importLocalBookNotification")
}
