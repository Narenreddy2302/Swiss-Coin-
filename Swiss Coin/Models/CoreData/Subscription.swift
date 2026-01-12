//
//  Subscription.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Subscription)
public class Subscription: NSManagedObject {

}

extension Subscription {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Subscription> {
        return NSFetchRequest<Subscription>(entityName: "Subscription")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var amount: Double
    @NSManaged public var cycle: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var isShared: Bool
    @NSManaged public var subscribers: NSSet?

}

extension Subscription: Identifiable {

}
