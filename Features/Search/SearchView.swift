//
//  SearchView.swift
//  Legado-iOS
//
//  搜索界面
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("搜索功能开发中")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("发现")
            .searchable(text: $searchText, prompt: "搜索书籍")
        }
    }
}

#Preview {
    SearchView()
}
