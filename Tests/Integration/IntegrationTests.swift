import XCTest
import CoreData
@testable import Legado

final class IntegrationTests: XCTestCase {
    
    var persistentContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        persistentContainer = NSPersistentContainer(name: "Legado")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData 加载失败: \(error)")
            }
        }
    }
    
    override func tearDownWithError() throws {
        persistentContainer = nil
    }
    
    // MARK: - 书籍导入集成测试
    
    func testBookImportFlow() async throws {
        let context = persistentContainer.viewContext
        
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.author = "测试作者"
        book.bookUrl = "https://example.com/book/1"
        book.origin = "local"
        
        try context.save()
        
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        let books = try context.fetch(request)
        
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.name, "测试书籍")
    }
    
    // MARK: - 书源导入集成测试
    
    func testBookSourceImport() async throws {
        let jsonString = """
        {
            "bookSourceUrl": "https://example.com",
            "bookSourceName": "测试书源",
            "bookSourceGroup": "测试组"
        }
        """
        
        let expectation = self.expectation(description: "导入完成")
        
        URLSchemeHandler.importBookSourceJSON(jsonString) { result in
            if case .success(let message) = result {
                XCTAssertNotNil(message)
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5)
    }
    
    // MARK: - 阅读进度保存测试
    
    func testReadingProgressSave() async throws {
        let context = persistentContainer.viewContext
        
        let book = Book.create(in: context)
        book.name = "进度测试书"
        book.durChapterIndex = 5
        book.durChapterPos = 100
        book.durChapterTime = Int64(Date().timeIntervalSince1970)
        
        try context.save()
        
        let savedBook = try context.fetch(Book.fetchRequest()).first
        XCTAssertEqual(savedBook?.durChapterIndex, 5)
        XCTAssertEqual(savedBook?.durChapterPos, 100)
    }
    
    // MARK: - 书架排序测试
    
    func testBookshelfSorting() async throws {
        let context = persistentContainer.viewContext
        
        let book1 = Book.create(in: context)
        book1.name = "A书籍"
        book1.durChapterTime = 100
        
        let book2 = Book.create(in: context)
        book2.name = "B书籍"
        book2.durChapterTime = 200
        
        try context.save()
        
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "durChapterTime", ascending: false)]
        
        let books = try context.fetch(request)
        XCTAssertEqual(books.first?.name, "B书籍")
    }
    
    // MARK: - 规则引擎集成测试
    
    func testRuleEngineIntegration() async throws {
        let engine = RuleEngine()
        
        let html = "<div class='content'>测试内容</div>"
        let rule = "div.content@text"
        
        let result = engine.parseRule(html, rule: rule)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("测试内容") ?? false)
    }
    
    // MARK: - 替换引擎集成测试
    
    func testReplaceEngineIntegration() {
        let engine = ReplaceEngine()
        
        let context = persistentContainer.viewContext
        let rule = ReplaceRule.create(in: context)
        rule.name = "测试替换"
        rule.pattern = "广告"
        rule.replacement = ""
        rule.enabled = true
        
        let content = "这是广告内容"
        let result = engine.applyRules(to: content, rules: [rule])
        
        XCTAssertFalse(result.contains("广告"))
    }
    
    // MARK: - CoreData 实体关系测试
    
    func testBookChapterRelationship() async throws {
        let context = persistentContainer.viewContext
        
        let book = Book.create(in: context)
        book.name = "章节测试书"
        book.totalChapterNum = 10
        
        for i in 0..<10 {
            let chapter = BookChapter.create(in: context)
            chapter.index = Int32(i)
            chapter.title = "第\(i+1)章"
            chapter.book = book
        }
        
        try context.save()
        
        let savedBook = try context.fetch(Book.fetchRequest()).first
        let chapters = savedBook?.chapters as? Set<BookChapter>
        
        XCTAssertEqual(chapters?.count, 10)
    }
}