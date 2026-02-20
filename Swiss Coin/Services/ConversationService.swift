//
//  ConversationService.swift
//  Swiss Coin
//
//  Cross-user conversation + messaging lifecycle.
//  Manages conversations and direct messages between Swiss Coin users.
//

import Combine
import CoreData
import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "conversation")

@MainActor
final class ConversationService: ObservableObject {
    static let shared = ConversationService()

    @Published private(set) var isSubscribed = false

    private let client = SupabaseConfig.client
    private var messageChannel: RealtimeChannelV2?

    private init() {}

    // MARK: - Conversation Management

    /// Get or create a conversation with another user
    func getOrCreateConversation(
        with remoteProfileId: UUID,
        remoteName: String?,
        context: NSManagedObjectContext
    ) async throws -> Conversation {
        // 1. Check CoreData first
        let existing: Conversation? = await context.perform {
            let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            request.predicate = NSPredicate(format: "remoteParticipantId == %@", remoteProfileId as CVarArg)
            request.fetchLimit = 1
            return (try? context.fetch(request))?.first
        }

        if let existing { return existing }

        // 2. Check Supabase for existing conversation
        guard let userId = AuthManager.shared.currentUserId else {
            throw ConversationError.notAuthenticated
        }

        let remoteConversations: [ConversationDTO] = try await client.from("conversations")
            .select()
            .or("and(participant_a.eq.\(userId.uuidString),participant_b.eq.\(remoteProfileId.uuidString)),and(participant_a.eq.\(remoteProfileId.uuidString),participant_b.eq.\(userId.uuidString))")
            .execute().value

        if let remoteConvo = remoteConversations.first {
            // Create local CoreData entity from remote
            return await context.perform {
                let conversation = Conversation(context: context)
                conversation.id = remoteConvo.id
                conversation.remoteParticipantId = remoteProfileId
                conversation.remoteParticipantName = remoteName
                conversation.lastMessageAt = remoteConvo.lastMessageAt
                conversation.lastMessagePreview = remoteConvo.lastMessagePreview
                conversation.createdAt = remoteConvo.createdAt
                conversation.updatedAt = remoteConvo.updatedAt

                // Link to Person if exists
                let personRequest: NSFetchRequest<Person> = Person.fetchRequest()
                personRequest.predicate = NSPredicate(format: "linkedProfileId == %@", remoteProfileId as CVarArg)
                personRequest.fetchLimit = 1
                if let person = (try? context.fetch(personRequest))?.first {
                    conversation.linkedPerson = person
                }

                try? context.save()
                return conversation
            }
        }

        // 3. Create new conversation on Supabase
        let newId = UUID()
        let insertData: [String: String] = [
            "id": newId.uuidString,
            "participant_a": userId.uuidString,
            "participant_b": remoteProfileId.uuidString
        ]

        try await client.from("conversations")
            .insert(insertData)
            .execute()

        // Create local CoreData entity
        return await context.perform {
            let conversation = Conversation(context: context)
            conversation.id = newId
            conversation.remoteParticipantId = remoteProfileId
            conversation.remoteParticipantName = remoteName
            conversation.createdAt = Date()

            let personRequest: NSFetchRequest<Person> = Person.fetchRequest()
            personRequest.predicate = NSPredicate(format: "linkedProfileId == %@", remoteProfileId as CVarArg)
            personRequest.fetchLimit = 1
            if let person = (try? context.fetch(personRequest))?.first {
                conversation.linkedPerson = person
            }

            try? context.save()
            return conversation
        }
    }

    // MARK: - Messaging

    /// Send a message in a conversation (optimistic UI)
    func sendMessage(
        content: String,
        in conversation: Conversation,
        context: NSManagedObjectContext
    ) async throws {
        guard let userId = AuthManager.shared.currentUserId else {
            throw ConversationError.notAuthenticated
        }
        guard let conversationId = conversation.id else {
            throw ConversationError.invalidConversation
        }

        let messageId = UUID()
        let now = Date()

        // 1. Create DirectMessage in CoreData immediately (optimistic)
        let conversationObjectID = conversation.objectID
        await context.perform {
            let convo = context.object(with: conversationObjectID) as! Conversation

            let dm = DirectMessage(context: context)
            dm.id = messageId
            dm.content = content
            dm.senderId = userId
            dm.status = "sent"
            dm.isSynced = false
            dm.createdAt = now
            dm.conversation = convo

            convo.lastMessageAt = now
            convo.lastMessagePreview = String(content.prefix(100))

            try? context.save()
        }

        // 2. INSERT into Supabase
        do {
            let insertData: [String: String] = [
                "id": messageId.uuidString,
                "conversation_id": conversationId.uuidString,
                "sender_id": userId.uuidString,
                "content": content
            ]

            try await client.from("direct_messages")
                .insert(insertData)
                .execute()

            // 3. Mark as synced
            await context.perform {
                let request: NSFetchRequest<DirectMessage> = DirectMessage.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", messageId as CVarArg)
                request.fetchLimit = 1
                if let dm = (try? context.fetch(request))?.first {
                    dm.isSynced = true
                    try? context.save()
                }
            }
        } catch {
            // Message stays in queue with isSynced = false for later retry
            logger.error("Failed to sync message \(messageId): \(error.localizedDescription)")
        }
    }

    // MARK: - Real-time Subscription

    /// Subscribe to incoming direct messages via Supabase Realtime
    func subscribeToMessages(context: NSManagedObjectContext) async {
        guard !isSubscribed else { return }
        guard let userId = AuthManager.shared.currentUserId else { return }

        let channel = client.realtimeV2.channel("direct-messages-\(userId.uuidString)")

        let onChange = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "direct_messages"
        )

        Task {
            for await action in onChange {
                // Decode the inserted message
                guard let record = try? action.decodeRecord(as: DirectMessageDTO.self, decoder: SupabaseConfig.decoder) else { continue }

                // Ignore own messages (already created locally)
                if record.senderId == userId { continue }

                // Create DirectMessage in CoreData
                await context.perform {
                    // Find or create conversation
                    let convoRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
                    convoRequest.predicate = NSPredicate(format: "id == %@", record.conversationId as CVarArg)
                    convoRequest.fetchLimit = 1
                    let conversation = (try? context.fetch(convoRequest))?.first ?? {
                        let c = Conversation(context: context)
                        c.id = record.conversationId
                        c.remoteParticipantId = record.senderId
                        c.createdAt = Date()
                        return c
                    }()

                    // Check for duplicate
                    let dmRequest: NSFetchRequest<DirectMessage> = DirectMessage.fetchRequest()
                    dmRequest.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
                    dmRequest.fetchLimit = 1
                    if (try? context.fetch(dmRequest))?.first != nil { return }

                    let dm = DirectMessage(context: context)
                    dm.id = record.id
                    dm.content = record.content
                    dm.senderId = record.senderId
                    dm.status = "delivered"
                    dm.isSynced = true
                    dm.createdAt = record.createdAt
                    dm.conversation = conversation

                    conversation.lastMessageAt = record.createdAt
                    conversation.lastMessagePreview = String(record.content.prefix(100))
                    conversation.unreadCount += 1

                    try? context.save()
                }

                // Send delivery receipt
                Task {
                    try? await client.from("direct_messages")
                        .update(["status": "delivered"])
                        .eq("id", value: record.id.uuidString)
                        .execute()
                }
            }
        }

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.error("Failed to subscribe to DM channel: \(error.localizedDescription)")
            return
        }

        messageChannel = channel
        isSubscribed = true
        logger.info("Subscribed to direct messages for user \(userId.uuidString)")
    }

    /// Unsubscribe from real-time messages
    func unsubscribe() async {
        if let channel = messageChannel {
            await channel.unsubscribe()
        }
        messageChannel = nil
        isSubscribed = false
    }

    // MARK: - Sync Helpers

    /// Push unsynced direct messages to Supabase
    func pushUnsyncedMessages(context: NSManagedObjectContext) async throws {
        guard let userId = AuthManager.shared.currentUserId else { return }

        let unsyncedMessages: [(id: UUID, conversationId: UUID, content: String, createdAt: Date)] = await context.perform {
            let request: NSFetchRequest<DirectMessage> = DirectMessage.fetchRequest()
            request.predicate = NSPredicate(format: "isSynced == NO AND senderId == %@", userId as CVarArg)
            let messages = (try? context.fetch(request)) ?? []
            return messages.compactMap { dm in
                guard let id = dm.id, let convoId = dm.conversation?.id, let content = dm.content, let createdAt = dm.createdAt else { return nil }
                return (id: id, conversationId: convoId, content: content, createdAt: createdAt)
            }
        }

        for msg in unsyncedMessages {
            let insertData: [String: String] = [
                "id": msg.id.uuidString,
                "conversation_id": msg.conversationId.uuidString,
                "sender_id": userId.uuidString,
                "content": msg.content
            ]

            do {
                try await client.from("direct_messages")
                    .upsert(insertData)
                    .execute()

                await context.perform {
                    let request: NSFetchRequest<DirectMessage> = DirectMessage.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", msg.id as CVarArg)
                    request.fetchLimit = 1
                    if let dm = (try? context.fetch(request))?.first {
                        dm.isSynced = true
                        try? context.save()
                    }
                }
            } catch {
                logger.error("Failed to push message \(msg.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Error Types

    enum ConversationError: LocalizedError {
        case notAuthenticated
        case invalidConversation

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Not authenticated"
            case .invalidConversation: return "Invalid conversation"
            }
        }
    }
}
