//
//  SupabaseDataService.swift
//  Swiss Coin
//
//  Concrete implementation of remote data operations against Supabase PostgREST.
//  All methods are async and work with DTO types for clean separation from CoreData.
//

import Foundation
import Supabase

@MainActor
final class SupabaseDataService {
    static let shared = SupabaseDataService()
    private let client = SupabaseConfig.client

    private var ownerId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }

    // MARK: - Persons

    func fetchPersons(since: Date? = nil) async throws -> [PersonDTO] {
        var query = client.from("persons").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.execute().value
    }

    func upsertPerson(_ person: PersonDTO) async throws {
        try await client.from("persons").upsert(person).execute()
    }

    func upsertPersons(_ persons: [PersonDTO]) async throws {
        guard !persons.isEmpty else { return }
        try await client.from("persons").upsert(persons).execute()
    }

    func softDeletePerson(id: UUID) async throws {
        try await client.from("persons")
            .update(["deleted_at": formatISO8601(Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - User Groups

    func fetchGroups(since: Date? = nil) async throws -> [GroupDTO] {
        var query = client.from("user_groups").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.execute().value
    }

    func upsertGroup(_ group: GroupDTO) async throws {
        try await client.from("user_groups").upsert(group).execute()
    }

    func upsertGroups(_ groups: [GroupDTO]) async throws {
        guard !groups.isEmpty else { return }
        try await client.from("user_groups").upsert(groups).execute()
    }

    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMemberDTO] {
        try await client.from("group_members")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .execute().value
    }

    func setGroupMembers(groupId: UUID, personIds: [UUID]) async throws {
        // Delete existing members
        try await client.from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .execute()

        // Insert new members
        let members = personIds.map { GroupMemberDTO(groupId: groupId, personId: $0) }
        if !members.isEmpty {
            try await client.from("group_members").insert(members).execute()
        }
    }

    // MARK: - Financial Transactions

    func fetchTransactions(since: Date? = nil) async throws -> [TransactionDTO] {
        var query = client.from("financial_transactions").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.order("date", ascending: false).execute().value
    }

    func upsertTransaction(_ transaction: TransactionDTO) async throws {
        try await client.from("financial_transactions").upsert(transaction).execute()
    }

    func upsertTransactions(_ transactions: [TransactionDTO]) async throws {
        guard !transactions.isEmpty else { return }
        try await client.from("financial_transactions").upsert(transactions).execute()
    }

    func fetchSplits(transactionId: UUID) async throws -> [TransactionSplitDTO] {
        try await client.from("transaction_splits")
            .select()
            .eq("transaction_id", value: transactionId.uuidString)
            .execute().value
    }

    func upsertSplits(_ splits: [TransactionSplitDTO]) async throws {
        guard !splits.isEmpty else { return }
        try await client.from("transaction_splits").upsert(splits).execute()
    }

    func replaceSplits(transactionId: UUID, splits: [TransactionSplitDTO]) async throws {
        try await client.from("transaction_splits")
            .delete()
            .eq("transaction_id", value: transactionId.uuidString)
            .execute()

        if !splits.isEmpty {
            try await client.from("transaction_splits").insert(splits).execute()
        }
    }

    func fetchPayers(transactionId: UUID) async throws -> [TransactionPayerDTO] {
        try await client.from("transaction_payers")
            .select()
            .eq("transaction_id", value: transactionId.uuidString)
            .execute().value
    }

    func upsertPayers(_ payers: [TransactionPayerDTO]) async throws {
        guard !payers.isEmpty else { return }
        try await client.from("transaction_payers").upsert(payers).execute()
    }

    func replacePayers(transactionId: UUID, payers: [TransactionPayerDTO]) async throws {
        try await client.from("transaction_payers")
            .delete()
            .eq("transaction_id", value: transactionId.uuidString)
            .execute()

        if !payers.isEmpty {
            try await client.from("transaction_payers").insert(payers).execute()
        }
    }

    // MARK: - Settlements

    func fetchSettlements(since: Date? = nil) async throws -> [SettlementDTO] {
        var query = client.from("settlements").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.order("date", ascending: false).execute().value
    }

    func upsertSettlement(_ settlement: SettlementDTO) async throws {
        try await client.from("settlements").upsert(settlement).execute()
    }

    func upsertSettlements(_ settlements: [SettlementDTO]) async throws {
        guard !settlements.isEmpty else { return }
        try await client.from("settlements").upsert(settlements).execute()
    }

    // MARK: - Reminders

    func fetchReminders(since: Date? = nil) async throws -> [ReminderDTO] {
        var query = client.from("reminders").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.execute().value
    }

    func upsertReminder(_ reminder: ReminderDTO) async throws {
        try await client.from("reminders").upsert(reminder).execute()
    }

    func upsertReminders(_ reminders: [ReminderDTO]) async throws {
        guard !reminders.isEmpty else { return }
        try await client.from("reminders").upsert(reminders).execute()
    }

    // MARK: - Chat Messages

    func fetchMessages(since: Date? = nil) async throws -> [MessageDTO] {
        var query = client.from("chat_messages").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.order("timestamp", ascending: false).execute().value
    }

    func upsertMessage(_ message: MessageDTO) async throws {
        try await client.from("chat_messages").upsert(message).execute()
    }

    func upsertMessages(_ messages: [MessageDTO]) async throws {
        guard !messages.isEmpty else { return }
        try await client.from("chat_messages").upsert(messages).execute()
    }

    // MARK: - Subscriptions

    func fetchSubscriptions(since: Date? = nil) async throws -> [SubscriptionDTO] {
        var query = client.from("subscriptions").select()
        if let since {
            query = query.gte("updated_at", value: formatISO8601(since))
        }
        return try await query.execute().value
    }

    func upsertSubscription(_ subscription: SubscriptionDTO) async throws {
        try await client.from("subscriptions").upsert(subscription).execute()
    }

    func upsertSubscriptions(_ subscriptions: [SubscriptionDTO]) async throws {
        guard !subscriptions.isEmpty else { return }
        try await client.from("subscriptions").upsert(subscriptions).execute()
    }

    func fetchSubscriptionSubscribers(subscriptionId: UUID) async throws -> [SubscriptionSubscriberDTO] {
        try await client.from("subscription_subscribers")
            .select()
            .eq("subscription_id", value: subscriptionId.uuidString)
            .execute().value
    }

    func setSubscriptionSubscribers(subscriptionId: UUID, personIds: [UUID]) async throws {
        try await client.from("subscription_subscribers")
            .delete()
            .eq("subscription_id", value: subscriptionId.uuidString)
            .execute()

        let subs = personIds.map { SubscriptionSubscriberDTO(subscriptionId: subscriptionId, personId: $0) }
        if !subs.isEmpty {
            try await client.from("subscription_subscribers").insert(subs).execute()
        }
    }

    func fetchSubscriptionPayments(subscriptionId: UUID) async throws -> [SubscriptionPaymentDTO] {
        try await client.from("subscription_payments")
            .select()
            .eq("subscription_id", value: subscriptionId.uuidString)
            .execute().value
    }

    func upsertSubscriptionPayments(_ payments: [SubscriptionPaymentDTO]) async throws {
        guard !payments.isEmpty else { return }
        try await client.from("subscription_payments").upsert(payments).execute()
    }

    func fetchSubscriptionSettlements(subscriptionId: UUID) async throws -> [SubscriptionSettlementDTO] {
        try await client.from("subscription_settlements")
            .select()
            .eq("subscription_id", value: subscriptionId.uuidString)
            .execute().value
    }

    func upsertSubscriptionSettlements(_ settlements: [SubscriptionSettlementDTO]) async throws {
        guard !settlements.isEmpty else { return }
        try await client.from("subscription_settlements").upsert(settlements).execute()
    }

    func fetchSubscriptionReminders(subscriptionId: UUID) async throws -> [SubscriptionReminderDTO] {
        try await client.from("subscription_reminders")
            .select()
            .eq("subscription_id", value: subscriptionId.uuidString)
            .execute().value
    }

    func upsertSubscriptionReminders(_ reminders: [SubscriptionReminderDTO]) async throws {
        guard !reminders.isEmpty else { return }
        try await client.from("subscription_reminders").upsert(reminders).execute()
    }

    // MARK: - Profile

    func fetchProfile() async throws -> ProfileDTO? {
        guard let userId = await ownerId else { return nil }
        let profiles: [ProfileDTO] = try await client.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute().value
        return profiles.first
    }

    func updateProfile(_ profile: ProfileDTO) async throws {
        try await client.from("profiles")
            .update(profile)
            .eq("id", value: profile.id.uuidString)
            .execute()
    }

    /// Upsert profile — safe create-or-update for profile setup
    func upsertProfile(_ profile: ProfileDTO) async throws {
        try await client.from("profiles").upsert(profile).execute()
    }

    // MARK: - Conversations

    func fetchConversations() async throws -> [ConversationDTO] {
        try await client.from("conversations")
            .select()
            .order("last_message_at", ascending: false)
            .execute().value
    }

    func fetchDirectMessages(conversationId: UUID, since: Date? = nil) async throws -> [DirectMessageDTO] {
        var query = client.from("direct_messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
        if let since {
            query = query.gte("created_at", value: formatISO8601(since))
        }
        return try await query.order("created_at", ascending: true).execute().value
    }

    // MARK: - Transaction Participants

    func fetchPendingParticipations() async throws -> [TransactionParticipantDTO] {
        guard let userId = await ownerId else { return [] }
        return try await client.from("transaction_participants")
            .select()
            .eq("profile_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute().value
    }

    func upsertTransactionParticipant(_ participant: TransactionParticipantDTO) async throws {
        try await client.from("transaction_participants").upsert(participant).execute()
    }

    func updateParticipantStatus(id: UUID, status: String) async throws {
        try await client.from("transaction_participants")
            .update(["status": status, "responded_at": formatISO8601(Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Settlement Participants

    func fetchPendingSettlementParticipations() async throws -> [SettlementParticipantDTO] {
        guard let userId = await ownerId else { return [] }
        return try await client.from("settlement_participants")
            .select()
            .eq("profile_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute().value
    }

    func updateSettlementParticipantStatus(id: UUID, status: String) async throws {
        try await client.from("settlement_participants")
            .update(["status": status, "responded_at": formatISO8601(Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Subscription Participants

    func updateSubscriptionParticipantStatus(id: UUID, status: String) async throws {
        try await client.from("subscription_participants")
            .update(["status": status, "responded_at": formatISO8601(Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Shared Reminders

    func fetchSharedReminders() async throws -> [SharedReminderDTO] {
        guard let userId = await ownerId else { return [] }
        return try await client.from("shared_reminders")
            .select()
            .eq("to_profile_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute().value
    }

    func upsertSharedReminder(_ reminder: SharedReminderDTO) async throws {
        try await client.from("shared_reminders").upsert(reminder).execute()
    }

    // MARK: - Device Tokens

    func upsertDeviceToken(userId: UUID, token: String) async throws {
        let data: [String: String] = [
            "user_id": userId.uuidString,
            "token": token,
            "platform": "ios"
        ]
        try await client.from("device_tokens").upsert(data).execute()
    }
}

// MARK: - Date Helper

/// Nonisolated ISO 8601 formatter — thread-safe, no actor isolation needed
nonisolated(unsafe) private let _iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func formatISO8601(_ date: Date) -> String {
    _iso8601Formatter.string(from: date)
}
