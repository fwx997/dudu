//
//  ShelfStore.swift
//  Legado-iOS
//
//  多书架管理（对齐香色闺阁 LCRecordGroupManagerV3 的分组体系）
//  书架 = BookGroup 分组；删除书架时书籍移入默认书架
//

import Foundation
import CoreData

@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    struct Shelf: Identifiable, Equatable {
        let id: Int64
        var name: String
    }

    static let defaultShelfId: Int64 = 0

    @Published private(set) var shelves: [Shelf] = []
    @Published var currentShelfId: Int64 {
        didSet { UserDefaults.standard.set(currentShelfId, forKey: "dudu.currentShelfId") }
    }

    private init() {
        currentShelfId = Int64(UserDefaults.standard.integer(forKey: "dudu.currentShelfId"))
        refresh()
    }

    var currentName: String {
        shelves.first { $0.id == currentShelfId }?.name ?? "书架"
    }

    func refresh() {
        let context = CoreDataStack.shared.viewContext
        let request = BookGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        let groups = (try? context.fetch(request)) ?? []
        var list = [Shelf(id: Self.defaultShelfId, name: "默认书架")]
        for g in groups where g.groupId != Self.defaultShelfId {
            list.append(Shelf(id: g.groupId, name: g.groupName.isEmpty ? "未命名书架" : g.groupName))
        }
        shelves = list
        if !shelves.contains(where: { $0.id == currentShelfId }) {
            currentShelfId = Self.defaultShelfId
        }
    }

    func createShelf(named name: String) {
        let context = CoreDataStack.shared.viewContext
        let nextId = (shelves.map { $0.id }.max() ?? 0) + 1
        let group = BookGroup.create(in: context, groupId: nextId, groupName: name)
        group.order = Int32(nextId)
        group.show = true
        try? CoreDataStack.shared.save()
        refresh()
    }

    func renameShelf(id: Int64, to name: String) {
        guard id != Self.defaultShelfId, let context = context else { return }
        let request = BookGroup.fetchRequest()
        request.predicate = NSPredicate(format: "groupId == %lld", id)
        if let group = try? context.fetch(request).first {
            group.groupName = name
            try? CoreDataStack.shared.save()
            refresh()
        }
    }

    /// 删除书架：书移入默认书架（对齐 removeGroupByGroupKey:moveItemsToDefaultGroup）
    func deleteShelf(id: Int64) {
        guard id != Self.defaultShelfId, let context = context else { return }
        let bookRequest = Book.fetchRequest()
        bookRequest.predicate = NSPredicate(format: "group == %lld", id)
        if let books = try? context.fetch(bookRequest) {
            for b in books { b.group = 0 }
        }
        let request = BookGroup.fetchRequest()
        request.predicate = NSPredicate(format: "groupId == %lld", id)
        if let group = try? context.fetch(request).first {
            context.delete(group)
        }
        try? CoreDataStack.shared.save()
        refresh()
    }

    private var context: NSManagedObjectContext? {
        CoreDataStack.shared.viewContext
    }
}
