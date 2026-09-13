//
//  SearchViewModelTests.swift
//  Legado-iOSTests
//
//  搜索 ViewModel 单元测试
//

import XCTest
@testable import Legado

@MainActor
final class SearchViewModelTests: XCTestCase {
    
    var viewModel: SearchViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = SearchViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - 搜索测试
    
    func testSearchResultCreation() {
        let result = SearchViewModel.SearchResult(
            name: "测试书籍",
            author: "作者",
            coverUrl: "https://example.com/cover.jpg",
            intro: "简介",
            sourceName: "测试书源",
            sourceId: UUID(),
            bookUrl: "https://example.com/book/1"
        )
        
        XCTAssertEqual(result.displayName, "测试书籍")
        XCTAssertEqual(result.displayAuthor, "作者")
        XCTAssertNotNil(result.id)
    }
    
    // MARK: - 空搜索测试
    
    func testEmptySearch() async {
        await viewModel.search(keyword: "", sources: [])
        
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }
    
    // MARK: - 性能测试
    
    func testSearchPerformance() async {
        self.measure {
            Task {
                await viewModel.search(keyword: "测试", sources: [])
            }
        }
    }
}
