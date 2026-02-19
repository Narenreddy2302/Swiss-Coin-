//
//  Conversation.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Conversation)
public class Conversation: NSManagedObject {

}

extension Conversation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Conversation> {
        return NSFetchRequest<Conversation>(entityName: "Conversation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var remoteParticipantId: UUID?
    @NSManaged public var remoteParticipantName: String?
    @NSManaged public var remoteParticipantPhotoURL: String?
    @NSManaged public var lastMessageAt: Date?
    @NSManaged public var lastMessagePreview: String?
    @NSManaged public var unreadCount: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var directMessages: NSSet?
    @NSManaged public var linkedPerson: Person?

}

// MARK: Generated accessors for directMessages
extension Conversation {
    @objc(addDirectMessagesObject:)
    @NSManaged public func addToDirectMessages(_ value: DirectMessage)

    @objc(removeDirectMessagesObject:)
    @NSManaged public func removeFromDirectMessages(_ value: DirectMessage)

    @objc(addDirectMessages:)
    @NSManaged public func addToDirectMessages(_ values: NSSet)

    @objc(removeDirectMessages:)
    @NSManaged public func removeFromDirectMessages(_ values: NSSet)
}

extension Conversation: Identifiable {

}
