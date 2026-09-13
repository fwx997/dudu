//
//  Bookmark+CoreDataClass.swift
//  Legado-iOS
//
//  书签实体
//

import Foundation
import CoreData

@objc(Bookmark)
public class Bookmark: NSManagedObject {
    @NSManaged public var bookmarkId: UUID
    @NSManaged public var bookId: UUID
    @NSManaged public var chapterIndex: Int32
    @NSManaged public var chapterTitle: String
    @NSManaged public var content: String
    @NSManaged public var createDate: Date
    
    @NSManaged public var book: Book?
}

extension Bookmark {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Bookmark> {
        return NSFetchRequest<Bookmark>(entityName: "Bookmark")
    }
    
    static func create(in context: NSManagedObjectContext) -> Bookmark {
        let entity = NSEntityDescription.entity(forEntityName: "Bookmark", in: context)!
        let bookmark = Bookmark(entity: entity, insertInto: context)
        bookmark.bookmarkId = UUID()
        bookmark.createDate = Date()
        return bookmark
    }
}
