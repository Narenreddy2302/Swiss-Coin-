//
//  RealtimeService.swift
//  Swiss Coin
//
//  Manages Supabase real-time channel subscriptions for multi-device sync.
//  Subscribes to changes on user-owned tables and propagates updates
//  to CoreData via NotificationCenter.
//

import Combine
import CoreData
import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "realtime")

/// Notification posted when real-time changes arrive from Supabase.
/// The userInfo contains "table" (String) and "action" (String: INSERT/UPDATE/DELETE).
extension Notification.Name {
    static let supabaseRealtimeChange = Notification.Name("supabaseRealtimeChange")
}

@MainActor
final class RealtimeService: ObservableObject {
    static let shared = RealtimeService()

    @Published private(set) var isSubscribed = false

    private var channel: RealtimeChannelV2?

    private init() {}

    // MARK: - Subscribe

    /// Subscribe to real-time changes for the current user's data.
    /// Call after successful authentication.
    func subscribe() async {
        guard !isSubscribed else { return }
        guard let userId = AuthManager.shared.currentUserId else {
            logger.warning("Cannot subscribe to realtime — not authenticated")
            return
        }

        let channel = SupabaseConfig.client.realtimeV2.channel("user-sync-\(userId.uuidString)")

        // Listen for changes on key tables
        let tables = [
            "financial_transactions",
            "settlements",
            "chat_messages",
            "reminders",
            "subscriptions",
            "subscription_reminders",
        ]

        for table in tables {
            let onChange = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: .eq("owner_id", value: userId.uuidString)
            )

            Task {
                for await change in onChange {
                    logger.debug("Realtime change on \(table): \(String(describing: change))")
                    NotificationCenter.default.post(
                        name: .supabaseRealtimeChange,
                        object: nil,
                        userInfo: ["table": table]
                    )
                }
            }
        }

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.error("Failed to subscribe to realtime: \(error.localizedDescription)")
            return
        }
        self.channel = channel
        isSubscribed = true
        logger.info("Subscribed to realtime channel for user \(userId.uuidString)")

        // Also subscribe to cross-user direct messages
        let context = PersistenceController.shared.container.viewContext
        await ConversationService.shared.subscribeToMessages(context: context)
    }

    // MARK: - Unsubscribe

    /// Unsubscribe from real-time changes. Call on sign-out.
    func unsubscribe() async {
        if let channel {
            await channel.unsubscribe()
        }
        channel = nil
        isSubscribed = false
        logger.info("Unsubscribed from realtime channel")
    }
}
