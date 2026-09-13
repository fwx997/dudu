//
//  ReplaceRule+CoreDataClass.swift
//  Legado-iOS
//
//  替换规则 CoreData 实体
//

import Foundation
import CoreData

@objc(ReplaceRule)
public class ReplaceRule: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReplaceRule> {
        return NSFetchRequest<ReplaceRule>(entityName: "ReplaceRule")
    }
    
    @NSManaged public var ruleId: UUID
    @NSManaged public var name: String
    @NSManaged public var pattern: String
    @NSManaged public var replacement: String
    @NSManaged public var scope: String
    @NSManaged public var scopeId: String?
    @NSManaged public var isRegex: Bool
    @NSManaged public var enabled: Bool
    @NSManaged public var priority: Int32
    @NSManaged public var order: Int32
}

extension ReplaceRule {
    static func create(in context: NSManagedObjectContext) -> ReplaceRule {
        let rule = ReplaceRule(context: context)
        rule.ruleId = UUID()
        rule.name = ""
        rule.pattern = ""
        rule.replacement = ""
        rule.scope = "global"
        rule.scopeId = nil
        rule.isRegex = true
        rule.enabled = true
        rule.priority = 0
        rule.order = 0
        return rule
    }
    
    /// 从 ReplaceRuleItem 创建 CoreData 实体
    static func from(item: ReplaceRuleItem, in context: NSManagedObjectContext) -> ReplaceRule {
        let rule = create(in: context)
        rule.ruleId = item.id
        rule.name = item.name
        rule.pattern = item.pattern
        rule.replacement = item.replacement
        rule.scope = item.scope
        rule.scopeId = item.scopeId
        rule.isRegex = item.isRegex
        rule.enabled = item.enabled
        rule.priority = Int32(item.priority)
        rule.order = Int32(item.order)
        return rule
    }
}

// ReplaceRuleItem 结构体（用于 UI 层）
struct ReplaceRuleItem: Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var pattern: String = ""
    var replacement: String = ""
    var scope: String = "global"
    var scopeId: String?
    var isRegex: Bool = true
    var enabled: Bool = true
    var priority: Int = 0
    var order: Int = 0
    
    init(from rule: ReplaceRule) {
        self.id = rule.ruleId
        self.name = rule.name
        self.pattern = rule.pattern
        self.replacement = rule.replacement
        self.scope = rule.scope
        self.scopeId = rule.scopeId
        self.isRegex = rule.isRegex
        self.enabled = rule.enabled
        self.priority = Int(rule.priority)
        self.order = Int(rule.order)
    }
    
    init(id: UUID = UUID(), name: String, pattern: String, replacement: String = "", 
         scope: String = "global", scopeId: String? = nil, isRegex: Bool = true, 
         enabled: Bool = true, priority: Int = 0, order: Int = 0) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.scope = scope
        self.scopeId = scopeId
        self.isRegex = isRegex
        self.enabled = enabled
        self.priority = priority
        self.order = order
    }
}
