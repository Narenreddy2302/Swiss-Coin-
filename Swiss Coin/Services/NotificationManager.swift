//
//  NotificationManager.swift
//  Swiss Coin
//
//  Manages local push notifications for payment reminders
//  and reminder follow-ups using UNUserNotificationCenter.
//

import Combine
import CoreData
import Foundation
import os
@preconcurrency import UserNotifications

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
            AppLogger.notifications.error("Failed to request notification permission: \(error.localizedDescription)")
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
                AppLogger.notifications.error("Failed to schedule reminder follow-up: \(error.localizedDescription)")
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
