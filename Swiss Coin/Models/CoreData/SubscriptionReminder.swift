//
//  SubscriptionReminder.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(SubscriptionReminder)
public class SubscriptionReminder: NSManagedObject {

}

extension SubscriptionReminder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionReminder> {
        return NSFetchRequest<SubscriptionReminder>(entityName: "SubscriptionReminder")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdDate: Date?
    @NSManaged public var amount: Double
    @NSManaged public var message: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var subscription: Subscription?
    @NSManaged public var toPerson: Person?

}

extension SubscriptionReminder: Identifiable {

}
