//
//  ReplaceEngineTests.swift
//  Legado-iOSTests
//
//  替换规则引擎单元测试
//

import XCTest
@testable import Legado

final class ReplaceEngineTests: XCTestCase {
    
    var replaceEngine: ReplaceEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        replaceEngine = ReplaceEngine.shared
    }
    
    override func tearDown() async throws {
        replaceEngine = nil
        try await super.tearDown()
    }
    
    // MARK: - 文本替换测试
    
    func testTextReplacement() {
        let context = CoreDataStack.shared.viewContext
        let rule = ReplaceRule.create(in: context)
        rule.name = "测试规则"
        rule.pattern = "广告"
        rule.replacement = "***"
        rule.isRegex = false
        rule.enabled = true
        rule.priority = 0
        
        let text = "这是广告内容"
        let result = replaceEngine.apply(text: text, rules: [rule])
        
        XCTAssertEqual(result, "这是***内容")
    }
    
    // MARK: - 正则替换测试
    
    func testRegexReplacement() {
        let context = CoreDataStack.shared.viewContext
        let rule = ReplaceRule.create(in: context)
        rule.name = "正则规则"
        rule.pattern = #"\d+"#
        rule.replacement = "数字"
        rule.isRegex = true
        rule.enabled = true
        rule.priority = 0
        
        let text = "第 123 章"
        let result = replaceEngine.apply(text: text, rules: [rule])
        
        XCTAssertEqual(result, "第数字章")
    }
    
    // MARK: - 多规则优先级测试
    
    func testMultipleRulesPriority() {
        let context = CoreDataStack.shared.viewContext
        
        let rule1 = ReplaceRule.create(in: context)
        rule1.name = "低优先级"
        rule1.pattern = "测试"
        rule1.replacement = "替换 1"
        rule1.isRegex = false
        rule1.enabled = true
        rule1.priority = 1
        
        let rule2 = ReplaceRule.create(in: context)
        rule2.name = "高优先级"
        rule2.pattern = "测试"
        rule2.replacement = "替换 2"
        rule2.isRegex = false
        rule2.enabled = true
        rule2.priority = 10
        
        let text = "测试内容"
        let result = replaceEngine.apply(text: text, rules: [rule1, rule2])
        
        // 高优先级规则先执行
        XCTAssertEqual(result, "替换 2 内容")
    }
    
    // MARK: - 禁用规则测试
    
    func testDisabledRule() {
        let context = CoreDataStack.shared.viewContext
        let rule = ReplaceRule.create(in: context)
        rule.name = "禁用规则"
        rule.pattern = "测试"
        rule.replacement = "替换"
        rule.isRegex = false
        rule.enabled = false
        rule.priority = 0
        
        let text = "测试内容"
        let result = replaceEngine.apply(text: text, rules: [rule])
        
        // 规则被禁用，不应替换
        XCTAssertEqual(result, text)
    }
    
    // MARK: - 性能测试
    
    func testReplacementPerformance() {
        let context = CoreDataStack.shared.viewContext
        let rules: [ReplaceRule] = (0..<10).map { i in
            let rule = ReplaceRule.create(in: context)
            rule.name = "规则\(i)"
            rule.pattern = "测试\(i)"
            rule.replacement = "替换\(i)"
            rule.isRegex = false
            rule.enabled = true
            rule.priority = Int32(i)
            return rule
        }
        
        let text = "测试内容 0-9"
        
        self.measure {
            _ = replaceEngine.apply(text: text, rules: rules)
        }
    }
}
