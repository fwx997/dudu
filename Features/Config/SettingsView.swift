//
//  SettingsView.swift
//  Legado-iOS
//
//  设置界面
//

import SwiftUI

struct SettingsLegacyView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("阅读")) {
                    NavigationLink("阅读设置") {
                        Text("阅读设置")
                    }
                    
                    NavigationLink("主题") {
                        Text("主题")
                    }
                }
                
                Section(header: Text("数据")) {
                    NavigationLink("备份与恢复") {
                        BackupRestoreView()
                    }
                    
                    NavigationLink("清理缓存") {
                        Text("清理缓存")
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("开源地址", destination: URL(string: "https://github.com/gedoor/legado")!)
                    
                    Link("帮助文档", destination: URL(string: "https://www.legado.top/")!)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
        }
    }
}

#Preview {
    SettingsLegacyView()
}
