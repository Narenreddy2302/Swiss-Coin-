//
//  Reminder.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Reminder)
public class Reminder: NSManagedObject {

}

extension Reminder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdDate: Date?
    @NSManaged public var amount: Double
    @NSManaged public var message: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var isCleared: Bool
    @NSManaged public var toPerson: Person?

}

extension Reminder: Identifiable {

}
