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

// MARK: Generated accessors for subscribers
extension Subscription {
    @objc(addSubscribersObject:)
    @NSManaged public func addToSubscribers(_ value: Person)

    @objc(removeSubscribersObject:)
    @NSManaged public func removeFromSubscribers(_ value: Person)

    @objc(addSubscribers:)
    @NSManaged public func addToSubscribers(_ values: NSSet)

    @objc(removeSubscribers:)
    @NSManaged public func removeFromSubscribers(_ values: NSSet)
}

extension Subscription: Identifiable {

}
