//
//  UserGroup.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(UserGroup)
public class UserGroup: NSManagedObject {
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

extension UserGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserGroup> {
        return NSFetchRequest<UserGroup>(entityName: "UserGroup")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var photoURL: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var lastViewedDate: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var members: NSSet?
    @NSManaged public var transactions: NSSet?
    @NSManaged public var chatMessages: NSSet?

}

// MARK: Generated accessors for members
extension UserGroup {
    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: Person)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: Person)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)
}

// MARK: Generated accessors for chatMessages
extension UserGroup {
    @objc(addChatMessagesObject:)
    @NSManaged public func addToChatMessages(_ value: ChatMessage)

    @objc(removeChatMessagesObject:)
    @NSManaged public func removeFromChatMessages(_ value: ChatMessage)

    @objc(addChatMessages:)
    @NSManaged public func addToChatMessages(_ values: NSSet)

    @objc(removeChatMessages:)
    @NSManaged public func removeFromChatMessages(_ values: NSSet)
}

// MARK: - Badge Activity Detection
extension UserGroup {
    /// Whether this group has new transactions since last viewed
    var hasNewActivity: Bool {
        let cutoff = max(
            lastViewedDate ?? .distantPast,
            CurrentUser.badgeFeatureActivationDate
        )
        if let txns = transactions as? Set<FinancialTransaction> {
            for txn in txns {
                if let d = txn.date, d > cutoff { return true }
            }
        }
        return false
    }
}

extension UserGroup: Identifiable {

}
