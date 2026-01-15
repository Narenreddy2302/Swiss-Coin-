//
//  SubscriptionSettlement.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(SubscriptionSettlement)
public class SubscriptionSettlement: NSManagedObject {

}

extension SubscriptionSettlement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionSettlement> {
        return NSFetchRequest<SubscriptionSettlement>(entityName: "SubscriptionSettlement")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var note: String?
    @NSManaged public var subscription: Subscription?
    @NSManaged public var fromPerson: Person?
    @NSManaged public var toPerson: Person?

}

extension SubscriptionSettlement: Identifiable {

}
