//
//  BookshelfViewModelTests.swift
//  Legado-iOS Tests
//
//  书架 ViewModel 单元测试
//

import XCTest
import CoreData
@testable import Legado

@MainActor
final class BookshelfViewModelTests: XCTestCase {
    
    var viewModel: BookshelfViewModel!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        context = CoreDataStack.shared.viewContext
        try await deleteAllBooks()
        viewModel = BookshelfViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await deleteAllBooks()
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试空书架
    func testEmptyBookshelf() async {
        await viewModel.loadBooks()
        
        XCTAssertTrue(viewModel.books.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    /// 测试添加书籍
    func testAddBook() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.author = "测试作者"
        book.durChapterTime = Int64(Date().timeIntervalSince1970)
        try context.save()
        
        await viewModel.loadBooks()
        
        XCTAssertEqual(viewModel.books.count, 1)
        XCTAssertEqual(viewModel.books.first?.name, "测试书籍")
    }
    
    /// 测试删除书籍
    func testDeleteBook() async throws {
        let book = Book.create(in: context)
        book.name = "待删除书籍"
        try context.save()
        
        await viewModel.loadBooks()
        XCTAssertEqual(viewModel.books.count, 1)
        
        viewModel.removeBook(book)
        
        await viewModel.loadBooks()
        XCTAssertTrue(viewModel.books.isEmpty)
    }
    
    /// 测试书籍排序（按阅读时间）
    func testBookSorting() async throws {
        let book1 = Book.create(in: context)
        book1.name = "书籍 A"
        book1.durChapterTime = Int64(Date().timeIntervalSince1970 - 1000)
        
        let book2 = Book.create(in: context)
        book2.name = "书籍 B"
        book2.durChapterTime = Int64(Date().timeIntervalSince1970)
        
        try context.save()
        
        await viewModel.loadBooks()
        
        XCTAssertEqual(viewModel.books.count, 2)
        XCTAssertEqual(viewModel.books.first?.name, "书籍 B")
    }
    
    /// 测试分页加载
    func testLazyLoading() async throws {
        // 创建 60 本书（超过 1 页）
        for i in 0..<60 {
            let book = Book.create(in: context)
            book.name = "书籍\(i)"
            book.durChapterTime = Int64(Date().timeIntervalSince1970) - Int64(i)
        }
        try context.save()
        
        await viewModel.loadBooks()
        
        // 第一页应该是 50 本
        XCTAssertEqual(viewModel.books.count, 50)
        XCTAssertTrue(viewModel.hasMore)
        
        // 加载更多
        await viewModel.loadMoreBooks()
        
        // 应该是 60 本
        XCTAssertEqual(viewModel.books.count, 60)
        XCTAssertFalse(viewModel.hasMore)
    }
    
    /// 测试分组过滤
    func testGroupFilter() async throws {
        let book1 = Book.create(in: context)
        book1.name = "分组 1 - 书籍"
        book1.group = 1
        
        let book2 = Book.create(in: context)
        book2.name = "分组 2 - 书籍"
        book2.group = 2
        
        try context.save()
        
        viewModel.groupFilter = 1
        await viewModel.loadBooks()
        
        XCTAssertEqual(viewModel.books.count, 1)
        XCTAssertEqual(viewModel.books.first?.group, 1)
    }
    
    // MARK: - 辅助方法
    
    private func deleteAllBooks() async throws {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        let books = try context.fetch(request)
        books.forEach { context.delete($0) }
        try context.save()
    }
}
