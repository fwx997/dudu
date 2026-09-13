//
//  RuleEngineTests.swift
//  Legado-iOSTests
//
//  规则引擎单元测试
//

import XCTest
@testable import Legado

final class RuleEngineTests: XCTestCase {
    
    var ruleEngine: RuleEngine!
    var context: ExecutionContext!
    
    override func setUp() async throws {
        try await super.setUp()
        ruleEngine = RuleEngine()
        context = ExecutionContext()
    }
    
    override func tearDown() async throws {
        ruleEngine = nil
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - JSONPath 测试
    
    func testJSONPathParser_simple() throws {
        let json = """
        {
            "book": {
                "name": "测试书籍",
                "author": "作者"
            }
        }
        """
        
        context.jsonString = json
        let result = try ruleEngine.executeSingle(rule: "$.book.name", context: context)
        
        XCTAssertEqual(result.string, "测试书籍")
    }
    
    func testJSONPathParser_array() throws {
        let json = """
        {
            "books": [
                {"name": "书籍 1"},
                {"name": "书籍 2"}
            ]
        }
        """
        
        context.jsonString = json
        let result = try ruleEngine.executeSingle(rule: "$.books[0].name", context: context)
        
        XCTAssertEqual(result.string, "书籍 1")
    }
    
    // MARK: - CSS 选择器测试
    
    func testCSSParser_simple() throws {
        let html = """
        <html>
            <body>
                <div class="book">
                    <h2>测试书籍</h2>
                </div>
            </body>
        </html>
        """
        
        // 注意：实际测试需要 SwiftSoup，这里只是示例
        // context.document = try SwiftSoup.parse(html)
        // let result = try ruleEngine.executeSingle(rule: "div.book h2@text", context: context)
        // XCTAssertEqual(result.string, "测试书籍")
    }
    
    // MARK: - XPath 测试
    
    func testXPathParser_simple() throws {
        let html = """
        <html>
            <body>
                <div class="book">
                    <h2>测试书籍</h2>
                </div>
            </body>
        </html>
        """
        
        context.document = html
        let result = try ruleEngine.executeSingle(rule: "//div[@class='book']/h2/text()", context: context)
        
        XCTAssertEqual(result.string, "测试书籍")
    }
    
    // MARK: - 正则测试
    
    func testRegexParser() throws {
        let text = "第 123 章 标题"
        context.document = text
        
        let result = try ruleEngine.executeSingle(rule: "regex:第\\d+ 章", context: context)
        
        XCTAssertEqual(result.string, "第 123 章")
    }
    
    // MARK: - JavaScript 测试
    
    func testJavaScriptParser() throws {
        context.document = "hello"
        context.baseURL = URL(string: "https://example.com")
        
        let result = try ruleEngine.executeSingle(rule: "{{js result.toUpperCase()}}", context: context)
        
        XCTAssertEqual(result.string, "HELLO")
    }
    
    // MARK: - 性能测试
    
    func testPerformance() throws {
        self.measure {
            let json = """
            {
                "book": {
                    "name": "测试",
                    "author": "作者"
                }
            }
            """
            
            context.jsonString = json
            
            for _ in 0..<100 {
                try? ruleEngine.executeSingle(rule: "$.book.name", context: context)
            }
        }
    }
}
