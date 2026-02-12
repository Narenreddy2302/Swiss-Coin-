//
//  Person.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Person)
public class Person: NSManagedObject {

}

extension Person {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Person> {
        return NSFetchRequest<Person>(entityName: "Person")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var phoneNumber: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var colorHex: String?
    @NSManaged public var isArchived: Bool
    @NSManaged public var toTransactions: NSSet?
    @NSManaged public var toGroups: NSSet?
    @NSManaged public var owedSplits: NSSet?
    @NSManaged public var sentSettlements: NSSet?
    @NSManaged public var receivedSettlements: NSSet?
    @NSManaged public var receivedReminders: NSSet?
    @NSManaged public var chatMessages: NSSet?
    @NSManaged public var createdTransactions: NSSet?
    @NSManaged public var payerSplits: NSSet?

}

// MARK: Generated accessors for toTransactions
extension Person {
    @objc(addToTransactionsObject:)
    @NSManaged public func addToToTransactions(_ value: FinancialTransaction)

    @objc(removeToTransactionsObject:)
    @NSManaged public func removeFromToTransactions(_ value: FinancialTransaction)

    @objc(addToTransactions:)
    @NSManaged public func addToToTransactions(_ values: NSSet)

    @objc(removeToTransactions:)
    @NSManaged public func removeFromToTransactions(_ values: NSSet)
}

// MARK: Generated accessors for toGroups
extension Person {
    @objc(addToGroupsObject:)
    @NSManaged public func addToToGroups(_ value: UserGroup)

    @objc(removeToGroupsObject:)
    @NSManaged public func removeFromToGroups(_ value: UserGroup)

    @objc(addToGroups:)
    @NSManaged public func addToToGroups(_ values: NSSet)

    @objc(removeToGroups:)
    @NSManaged public func removeFromToGroups(_ values: NSSet)
}

// MARK: Generated accessors for sentSettlements
extension Person {
    @objc(addSentSettlementsObject:)
    @NSManaged public func addToSentSettlements(_ value: Settlement)

    @objc(removeSentSettlementsObject:)
    @NSManaged public func removeFromSentSettlements(_ value: Settlement)

    @objc(addSentSettlements:)
    @NSManaged public func addToSentSettlements(_ values: NSSet)

    @objc(removeSentSettlements:)
    @NSManaged public func removeFromSentSettlements(_ values: NSSet)
}

// MARK: Generated accessors for receivedSettlements
extension Person {
    @objc(addReceivedSettlementsObject:)
    @NSManaged public func addToReceivedSettlements(_ value: Settlement)

    @objc(removeReceivedSettlementsObject:)
    @NSManaged public func removeFromReceivedSettlements(_ value: Settlement)

    @objc(addReceivedSettlements:)
    @NSManaged public func addToReceivedSettlements(_ values: NSSet)

    @objc(removeReceivedSettlements:)
    @NSManaged public func removeFromReceivedSettlements(_ values: NSSet)
}

// MARK: Generated accessors for receivedReminders
extension Person {
    @objc(addReceivedRemindersObject:)
    @NSManaged public func addToReceivedReminders(_ value: Reminder)

    @objc(removeReceivedRemindersObject:)
    @NSManaged public func removeFromReceivedReminders(_ value: Reminder)

    @objc(addReceivedReminders:)
    @NSManaged public func addToReceivedReminders(_ values: NSSet)

    @objc(removeReceivedReminders:)
    @NSManaged public func removeFromReceivedReminders(_ values: NSSet)
}

// MARK: Generated accessors for chatMessages
extension Person {
    @objc(addChatMessagesObject:)
    @NSManaged public func addToChatMessages(_ value: ChatMessage)

    @objc(removeChatMessagesObject:)
    @NSManaged public func removeFromChatMessages(_ value: ChatMessage)

    @objc(addChatMessages:)
    @NSManaged public func addToChatMessages(_ values: NSSet)

    @objc(removeChatMessages:)
    @NSManaged public func removeFromChatMessages(_ values: NSSet)
}

// MARK: Generated accessors for owedSplits
extension Person {
    @objc(addOwedSplitsObject:)
    @NSManaged public func addToOwedSplits(_ value: TransactionSplit)

    @objc(removeOwedSplitsObject:)
    @NSManaged public func removeFromOwedSplits(_ value: TransactionSplit)

    @objc(addOwedSplits:)
    @NSManaged public func addToOwedSplits(_ values: NSSet)

    @objc(removeOwedSplits:)
    @NSManaged public func removeFromOwedSplits(_ values: NSSet)
}

// MARK: Generated accessors for createdTransactions
extension Person {
    @objc(addCreatedTransactionsObject:)
    @NSManaged public func addToCreatedTransactions(_ value: FinancialTransaction)

    @objc(removeCreatedTransactionsObject:)
    @NSManaged public func removeFromCreatedTransactions(_ value: FinancialTransaction)

    @objc(addCreatedTransactions:)
    @NSManaged public func addToCreatedTransactions(_ values: NSSet)

    @objc(removeCreatedTransactions:)
    @NSManaged public func removeFromCreatedTransactions(_ values: NSSet)
}

// MARK: Generated accessors for payerSplits
extension Person {
    @objc(addPayerSplitsObject:)
    @NSManaged public func addToPayerSplits(_ value: TransactionPayer)

    @objc(removePayerSplitsObject:)
    @NSManaged public func removeFromPayerSplits(_ value: TransactionPayer)

    @objc(addPayerSplits:)
    @NSManaged public func addToPayerSplits(_ values: NSSet)

    @objc(removePayerSplits:)
    @NSManaged public func removeFromPayerSplits(_ values: NSSet)
}

extension Person: Identifiable {

}
