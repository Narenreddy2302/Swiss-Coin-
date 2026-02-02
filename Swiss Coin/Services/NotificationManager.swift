//
//  NotificationManager.swift
//  Swiss Coin
//
//  Manages local push notifications for subscription billing reminders
//  and reminder follow-ups using UNUserNotificationCenter.
//

import CoreData
import Foundation
import UserNotifications

/// Singleton service for scheduling and managing local notifications.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Published Properties

    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private let center = UNUserNotificationCenter.current()

    // MARK: - Notification Identifiers

    private enum IdentifierPrefix {
        static let subscriptionReminder = "subscription-reminder-"
        static let reminderFollowUp = "reminder-followup-"
    }

    // MARK: - Init

    private override init() {
        super.init()
        Task {
            await refreshPermissionStatus()
        }
    }

    // MARK: - Permission Management

    /// Requests notification permission from the user.
    /// - Returns: `true` if permission was granted.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshPermissionStatus()
            return granted
        } catch {
            print("❌ NotificationManager: Failed to request permission — \(error.localizedDescription)")
            await refreshPermissionStatus()
            return false
        }
    }

    /// Refreshes the cached permission status from the system.
    func refreshPermissionStatus() async {
        let settings = await center.notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Whether notifications are currently authorized at the system level.
    var isAuthorized: Bool {
        permissionStatus == .authorized
    }

    // MARK: - Subscription Reminders

    /// Schedules a local notification reminder for a subscription's upcoming billing date.
    ///
    /// The notification fires `notificationDaysBefore` days before `nextBillingDate`.
    /// If notifications are disabled on the subscription or globally, this is a no-op.
    ///
    /// - Parameter subscription: The subscription to schedule a reminder for.
    func scheduleSubscriptionReminder(for subscription: Subscription) {
        // Guard: notification must be enabled on the subscription
        guard subscription.notificationEnabled else { return }

        // Guard: must have a valid ID and billing date
        guard let subscriptionId = subscription.id,
              let nextBillingDate = subscription.nextBillingDate else { return }

        // Guard: subscription must be active
        guard subscription.isActive else { return }

        // Check global notification preference
        let globalEnabled = UserDefaults.standard.object(forKey: "notifications_enabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "notifications_enabled")

        let subscriptionNotifyEnabled = UserDefaults.standard.object(forKey: "notify_subscription_due") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "notify_subscription_due")

        guard globalEnabled && subscriptionNotifyEnabled else { return }

        // Cancel any existing reminder for this subscription first
        cancelSubscriptionReminder(for: subscription)

        // Calculate the reminder date
        let daysBefore = max(1, Int(subscription.notificationDaysBefore))
        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: nextBillingDate) else { return }

        // Don't schedule if the reminder date is in the past
        guard reminderDate > Date() else { return }

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = "Subscription Due Soon"
        content.body = "\(subscription.name ?? "A subscription") (\(CurrencyFormatter.format(subscription.amount))) is due in \(daysBefore) day\(daysBefore == 1 ? "" : "s")."
        content.sound = .default
        content.categoryIdentifier = "SUBSCRIPTION_REMINDER"
        content.userInfo = [
            "subscriptionId": subscriptionId.uuidString,
            "type": "subscription_reminder"
        ]

        // Create a calendar-based trigger
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Create and schedule the request
        let identifier = "\(IdentifierPrefix.subscriptionReminder)\(subscriptionId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Failed to schedule subscription reminder — \(error.localizedDescription)")
            }
        }
    }

    /// Cancels a pending notification reminder for a subscription.
    ///
    /// - Parameter subscription: The subscription whose reminder should be cancelled.
    func cancelSubscriptionReminder(for subscription: Subscription) {
        guard let subscriptionId = subscription.id else { return }
        let identifier = "\(IdentifierPrefix.subscriptionReminder)\(subscriptionId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Recalculates and reschedules all pending subscription reminders.
    ///
    /// Cancels all existing subscription reminders and re-schedules based on current data.
    /// Call this after bulk changes or when notification settings change globally.
    ///
    /// - Parameter context: The Core Data context to fetch subscriptions from.
    func rescheduleAllSubscriptionReminders(in context: NSManagedObjectContext) {
        // Remove all existing subscription reminders
        center.getPendingNotificationRequests { [weak self] requests in
            let subscriptionIds = requests
                .filter { $0.identifier.hasPrefix(IdentifierPrefix.subscriptionReminder) }
                .map { $0.identifier }

            self?.center.removePendingNotificationRequests(withIdentifiers: subscriptionIds)

            // Fetch all active subscriptions with notifications enabled
            Task { @MainActor [weak self] in
                let fetchRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "isActive == YES AND notificationEnabled == YES")

                do {
                    let subscriptions = try context.fetch(fetchRequest)
                    for subscription in subscriptions {
                        self?.scheduleSubscriptionReminder(for: subscription)
                    }
                } catch {
                    print("❌ NotificationManager: Failed to fetch subscriptions for rescheduling — \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Reminder Follow-Ups

    /// Schedules a follow-up notification for when a reminder is sent to someone.
    ///
    /// - Parameters:
    ///   - reminderId: Unique identifier for the reminder.
    ///   - personName: Name of the person who was reminded.
    ///   - amount: The amount they owe.
    ///   - followUpDate: When to send the follow-up notification.
    func scheduleReminderFollowUp(
        reminderId: UUID,
        personName: String,
        amount: Double,
        followUpDate: Date
    ) {
        // Don't schedule if the date is in the past
        guard followUpDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder Follow-Up"
        content.body = "You reminded \(personName) about \(CurrencyFormatter.format(amount)). Check if they've paid."
        content.sound = .default
        content.categoryIdentifier = "REMINDER_FOLLOWUP"
        content.userInfo = [
            "reminderId": reminderId.uuidString,
            "type": "reminder_followup"
        ]

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: followUpDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "\(IdentifierPrefix.reminderFollowUp)\(reminderId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Failed to schedule reminder follow-up — \(error.localizedDescription)")
            }
        }
    }

    /// Cancels a pending reminder follow-up notification.
    ///
    /// - Parameter reminderId: The reminder UUID to cancel.
    func cancelReminderFollowUp(reminderId: UUID) {
        let identifier = "\(IdentifierPrefix.reminderFollowUp)\(reminderId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Utility

    /// Removes all pending and delivered notifications managed by this app.
    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Returns the count of pending notification requests (for debugging).
    func pendingNotificationCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }
}
