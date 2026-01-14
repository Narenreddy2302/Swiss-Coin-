//
//  HapticManager.swift
//  Swiss Coin
//
//  Centralized haptic feedback management for consistent tactile responses.
//

import UIKit

/// Centralized haptic feedback manager providing consistent tactile responses
/// throughout the app, following Apple's Human Interface Guidelines.
enum HapticManager {

    // MARK: - Shared Generators (retained for reliability)

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Preparation

    /// Prepares all haptic generators for immediate use.
    /// Call this on view appear for optimal response times.
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Impact Feedback

    /// Light impact for subtle interactions (toggles, small buttons)
    static func lightTap() {
        lightImpact.impactOccurred()
    }

    /// Medium impact for standard button presses
    static func tap() {
        mediumImpact.impactOccurred()
    }

    /// Heavy impact for significant actions
    static func heavyTap() {
        heavyImpact.impactOccurred()
    }

    /// Soft impact for gentle interactions
    static func softTap() {
        softImpact.impactOccurred()
    }

    /// Rigid impact for firm feedback
    static func rigidTap() {
        rigidImpact.impactOccurred()
    }

    // MARK: - Selection Feedback

    /// Selection changed feedback (picker scrolling, selection changes)
    static func selectionChanged() {
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success notification (completed actions, saved successfully)
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning notification (reminders, alerts)
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error notification (failed actions, validation errors)
    static func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Contextual Haptics

    /// Haptic for button press (primary actions)
    static func buttonPress() {
        mediumImpact.impactOccurred()
    }

    /// Haptic for navigation actions
    static func navigate() {
        lightImpact.impactOccurred()
    }

    /// Haptic for toggle/switch actions
    static func toggle() {
        lightImpact.impactOccurred()
    }

    /// Haptic for delete/destructive actions
    static func delete() {
        notification.notificationOccurred(.warning)
    }

    /// Haptic for send message action
    static func sendMessage() {
        mediumImpact.impactOccurred()
    }

    /// Haptic for save/confirm action
    static func save() {
        notification.notificationOccurred(.success)
    }

    /// Haptic for cancel action
    static func cancel() {
        lightImpact.impactOccurred()
    }

    /// Haptic for long press activation
    static func longPress() {
        heavyImpact.impactOccurred()
    }

    /// Haptic for context menu appearance
    static func contextMenu() {
        mediumImpact.impactOccurred()
    }
}
