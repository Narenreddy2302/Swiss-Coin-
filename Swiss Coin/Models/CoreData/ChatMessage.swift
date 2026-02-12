//
//  ChatMessage.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(ChatMessage)
public class ChatMessage: NSManagedObject {

}

extension ChatMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatMessage> {
        return NSFetchRequest<ChatMessage>(entityName: "ChatMessage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var isFromUser: Bool
    @NSManaged public var isEdited: Bool
    @NSManaged public var withPerson: Person?
    @NSManaged public var withGroup: UserGroup?
    @NSManaged public var withSubscription: Subscription?
    @NSManaged public var onTransaction: FinancialTransaction?

}

extension ChatMessage: Identifiable {

}
