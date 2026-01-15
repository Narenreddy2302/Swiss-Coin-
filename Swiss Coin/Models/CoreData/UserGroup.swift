//
//  UserGroup.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(UserGroup)
public class UserGroup: NSManagedObject {

}

extension UserGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserGroup> {
        return NSFetchRequest<UserGroup>(entityName: "UserGroup")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var colorHex: String?
    @NSManaged public var createdDate: Date?
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

extension UserGroup: Identifiable {

}
