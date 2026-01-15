//
//  SubscriptionPayment.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(SubscriptionPayment)
public class SubscriptionPayment: NSManagedObject {

}

extension SubscriptionPayment {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionPayment> {
        return NSFetchRequest<SubscriptionPayment>(entityName: "SubscriptionPayment")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var billingPeriodStart: Date?
    @NSManaged public var billingPeriodEnd: Date?
    @NSManaged public var note: String?
    @NSManaged public var subscription: Subscription?
    @NSManaged public var payer: Person?

}

extension SubscriptionPayment: Identifiable {

}
