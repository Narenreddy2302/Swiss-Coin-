//
//  Subscription.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Subscription)
public class Subscription: NSManagedObject {
    override public func willSave() {
        super.willSave()
        if hasChanges && !isDeleted {
            let now = Date()
            let current = primitiveValue(forKey: "updatedAt") as? Date
            if current == nil || now.timeIntervalSince(current!) > 1 {
                setPrimitiveValue(now, forKey: "updatedAt")
            }
        }
    }
}

extension Subscription {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Subscription> {
        return NSFetchRequest<Subscription>(entityName: "Subscription")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var amount: Double
    @NSManaged public var cycle: String?
    @NSManaged public var customCycleDays: Int16
    @NSManaged public var startDate: Date?
    @NSManaged public var nextBillingDate: Date?
    @NSManaged public var isShared: Bool
    @NSManaged public var isActive: Bool
    @NSManaged public var category: String?
    @NSManaged public var iconName: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var notes: String?
    @NSManaged public var notificationEnabled: Bool
    @NSManaged public var notificationDaysBefore: Int16
    @NSManaged public var isArchived: Bool
    @NSManaged public var updatedAt: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var sharingStatus: String?
    @NSManaged public var sharedByProfileId: UUID?
    @NSManaged public var subscribers: NSSet?
    @NSManaged public var payments: NSSet?
    @NSManaged public var chatMessages: NSSet?
    @NSManaged public var reminders: NSSet?
    @NSManaged public var settlements: NSSet?

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

// MARK: Generated accessors for payments
extension Subscription {
    @objc(addPaymentsObject:)
    @NSManaged public func addToPayments(_ value: SubscriptionPayment)

    @objc(removePaymentsObject:)
    @NSManaged public func removeFromPayments(_ value: SubscriptionPayment)

    @objc(addPayments:)
    @NSManaged public func addToPayments(_ values: NSSet)

    @objc(removePayments:)
    @NSManaged public func removeFromPayments(_ values: NSSet)
}

// MARK: Generated accessors for chatMessages
extension Subscription {
    @objc(addChatMessagesObject:)
    @NSManaged public func addToChatMessages(_ value: ChatMessage)

    @objc(removeChatMessagesObject:)
    @NSManaged public func removeFromChatMessages(_ value: ChatMessage)

    @objc(addChatMessages:)
    @NSManaged public func addToChatMessages(_ values: NSSet)

    @objc(removeChatMessages:)
    @NSManaged public func removeFromChatMessages(_ values: NSSet)
}

// MARK: Generated accessors for reminders
extension Subscription {
    @objc(addRemindersObject:)
    @NSManaged public func addToReminders(_ value: SubscriptionReminder)

    @objc(removeRemindersObject:)
    @NSManaged public func removeFromReminders(_ value: SubscriptionReminder)

    @objc(addReminders:)
    @NSManaged public func addToReminders(_ values: NSSet)

    @objc(removeReminders:)
    @NSManaged public func removeFromReminders(_ values: NSSet)
}

// MARK: Generated accessors for settlements
extension Subscription {
    @objc(addSettlementsObject:)
    @NSManaged public func addToSettlements(_ value: SubscriptionSettlement)

    @objc(removeSettlementsObject:)
    @NSManaged public func removeFromSettlements(_ value: SubscriptionSettlement)

    @objc(addSettlements:)
    @NSManaged public func addToSettlements(_ values: NSSet)

    @objc(removeSettlements:)
    @NSManaged public func removeFromSettlements(_ values: NSSet)
}

extension Subscription: Identifiable {

}
