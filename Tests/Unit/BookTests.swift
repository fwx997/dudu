//
//  BookTests.swift
//  Legado-iOSTests
//
//  Book 实体单元测试
//

import XCTest
import CoreData
@testable import Legado

final class BookTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        context = CoreDataStack.shared.viewContext
    }
    
    override func tearDown() async throws {
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - Book 创建测试
    
    func testBookCreation() throws {
        let book = Book.create(in: context)
        
        XCTAssertNotNil(book.bookId)
        XCTAssertEqual(book.type, 0)
        XCTAssertEqual(book.canUpdate, true)
        XCTAssertEqual(book.order, 0)
        XCTAssertEqual(book.group, 0)
    }
    
    // MARK: - Book 属性测试
    
    func testBookProperties() throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.author = "作者"
        book.coverUrl = "https://example.com/cover.jpg"
        book.intro = "简介内容"
        
        XCTAssertEqual(book.displayName, "测试书籍")
        XCTAssertEqual(book.displayAuthor, "作者")
    }
    
    // MARK: - 计算属性测试
    
    func testReadProgress() throws {
        let book = Book.create(in: context)
        book.totalChapterNum = 100
        book.durChapterIndex = 50
        
        XCTAssertEqual(book.readProgress, 0.5)
    }
    
    func testUnreadChapterNum() throws {
        let book = Book.create(in: context)
        book.totalChapterNum = 100
        book.durChapterIndex = 50
        
        XCTAssertEqual(book.unreadChapterNum, 49)
    }
    
    func testDisplayCoverUrl() throws {
        let book = Book.create(in: context)
        book.coverUrl = "https://example.com/cover.jpg"
        book.customCoverUrl = nil
        
        XCTAssertEqual(book.displayCoverUrl, "https://example.com/cover.jpg")
        
        book.customCoverUrl = "https://example.com/custom.jpg"
        XCTAssertEqual(book.displayCoverUrl, "https://example.com/custom.jpg")
    }
    
    // MARK: - ReadConfig 测试
    
    func testReadConfig() throws {
        let book = Book.create(in: context)
        
        // 测试默认配置
        let defaultConfig = book.readConfigObj
        XCTAssertEqual(defaultConfig.reverseToc, false)
        XCTAssertEqual(defaultConfig.pageAnim, 0)
        
        // 测试修改配置
        book.isReverseToc = true
        book.pageAnimation = 1
        
        let updatedConfig = book.readConfigObj
        XCTAssertEqual(updatedConfig.reverseToc, true)
        XCTAssertEqual(updatedConfig.pageAnim, 1)
    }
    
    // MARK: - 性能测试
    
    func testPerformance() throws {
        self.measure {
            for _ in 0..<100 {
                let book = Book.create(in: context)
                book.name = "测试书籍"
                book.author = "作者"
            }
            try? CoreDataStack.shared.save()
        }
    }
}
