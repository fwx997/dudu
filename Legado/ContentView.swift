//
//  ContentView.swift
//  Legado
//
//  主界面 - 书架
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Book.lastReadDate, order: .reverse) var books: [Book]
    @State private var selectedTab = 0
    @State private var showingImportSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 书架
            LibraryView(books: books)
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }
                .tag(0)
            
            // 书源
            BookSourcesView()
                .tabItem {
                    Label("书源", systemImage: "link")
                }
                .tag(1)
            
            // 发现
            DiscoveryView()
                .tabItem {
                    Label("发现", systemImage: "compass")
                }
                .tag(2)
            
            // 我的
            SettingsView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportBookView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Book.self, inMemory: true)
}
