//
//  DirectMessage.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(DirectMessage)
public class DirectMessage: NSManagedObject {

}

extension DirectMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectMessage> {
        return NSFetchRequest<DirectMessage>(entityName: "DirectMessage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var senderId: UUID?
    @NSManaged public var status: String?
    @NSManaged public var isEdited: Bool
    @NSManaged public var isSynced: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var conversation: Conversation?

}

extension DirectMessage: Identifiable {

}
