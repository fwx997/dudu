//
//  CoreDataStackTests.swift
//  Legado-iOS Tests
//
//  CoreData 栈单元测试
//

import XCTest
import CoreData
@testable import Legado

final class CoreDataStackTests: XCTestCase {
    
    var stack: CoreDataStack!
    
    override func setUp() async throws {
        try await super.setUp()
        stack = CoreDataStack.shared
    }
    
    override func tearDown() async throws {
        stack = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试单例
    func testSharedInstance() {
        let instance1 = CoreDataStack.shared
        let instance2 = CoreDataStack.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    /// 测试创建上下文
    func testCreateContext() {
        let context = stack.newBackgroundContext()
        
        XCTAssertNotNil(context)
        XCTAssertEqual(context.mergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    /// 测试保存数据
    func testSave() async throws {
        let context = stack.viewContext
        
        let book = Book.create(in: context)
        book.name = "测试书籍"
        
        try await stack.save(context: context)
        
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "测试书籍")
        let books = try context.fetch(request)
        
        XCTAssertEqual(books.count, 1)
    }
    
    /// 测试后台任务
    func testBackgroundTask() async throws {
        let result = try await stack.performBackgroundTask { context -> Int in
            let book = Book.create(in: context)
            book.name = "后台创建"
            return 42
        }
        
        XCTAssertEqual(result, 42)
        
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "后台创建")
        let books = try stack.viewContext.fetch(request)
        
        XCTAssertEqual(books.count, 1)
    }
    
    /// 测试 viewContext
    func testViewContext() {
        let context = stack.viewContext
        
        XCTAssertNotNil(context)
        XCTAssertEqual(context.concurrencyType, .mainQueueConcurrencyType)
    }
    
    /// 测试 iCloud 配置
    func testICloudConfiguration() {
        let container = stack.persistentContainer
        
        XCTAssertEqual(container.name, "Legado")
        XCTAssertGreaterThan(container.persistentStoreDescriptions.count, 0)
    }
}
