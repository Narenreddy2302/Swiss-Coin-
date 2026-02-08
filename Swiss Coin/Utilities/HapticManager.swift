//
//  HapticManager.swift
//  Swiss Coin
//
//  Centralized haptic feedback management for consistent user experience.
//  Provides intensity-controlled impacts, CoreHaptics patterns, and
//  contextual semantic actions matching Apple's HIG standards.
//

import CoreHaptics
import UIKit

/// Manages haptic feedback throughout the app.
/// Respects the user's haptic preference stored in `@AppStorage("haptic_feedback")`.
final class HapticManager {

    // MARK: - User Preference

    /// Whether haptic feedback is enabled. Defaults to true when the preference has never been set.
    private static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "haptic_feedback") == nil {
            return true  // Default: haptics enabled
        }
        return UserDefaults.standard.bool(forKey: "haptic_feedback")
    }

    // MARK: - Shared Generators

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()

    // MARK: - CoreHaptics Engine

    private static var hapticEngine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = {
            try? HapticManager.hapticEngine?.start()
        }
        try? engine?.start()
        return engine
    }()

    // MARK: - Preparation

    /// Prepares haptic generators for immediate use (call on view appear)
    static func prepare() {
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    // MARK: - Impact Feedback

    /// Light tap feedback for secondary actions
    static func lightTap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    /// Standard tap feedback for primary actions
    static func tap() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    /// Heavy tap feedback for important actions
    static func heavyTap() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
    }

    /// Rigid tap for crisp, precise feedback (context menu peek, confirmation)
    static func rigidTap() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
    }

    /// Soft tap for gentle, subtle feedback (sheet presentation, tooltip)
    static func softTap() {
        guard isEnabled else { return }
        softImpact.impactOccurred()
    }

    /// Impact with custom intensity (0.0 - 1.0)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: intensity)
    }

    // MARK: - Selection Feedback

    /// Selection change feedback for pickers, toggles, segments
    static func selectionChanged() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }

    /// Toggle state change feedback
    static func toggle() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success feedback for completed actions
    static func success() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning feedback for reversible errors
    static func warning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error feedback for failed actions
    static func error() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - Semantic Actions

    /// Feedback for save operations
    static func save() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    /// Feedback for cancel operations
    static func cancel() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    /// Feedback for delete operations
    static func delete() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }

    // MARK: - Conversation Haptics

    /// Message sent — crisp, satisfying confirmation like iMessage
    static func messageSent() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.6)
    }

    /// Message received — gentle notification tap
    static func messageReceived() {
        guard isEnabled else { return }
        softImpact.impactOccurred(intensity: 0.4)
    }

    /// Context menu peek — firm tap signaling long-press recognition
    static func contextMenuPeek() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.8)
    }

    /// Sheet presenting — soft thud as modal slides in
    static func sheetPresent() {
        guard isEnabled else { return }
        softImpact.impactOccurred(intensity: 0.5)
    }

    /// Sheet dismissing — lighter counterpart to presentation
    static func sheetDismiss() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.3)
    }

    /// Navigation push/pop — subtle directional feedback
    static func navigationTap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.4)
    }

    /// Action bar button press — medium, professional tap
    static func actionBarTap() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.7)
    }

    /// Primary action (Add expense, Record payment) — firm, deliberate
    static func primaryAction() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.8)
    }

    /// Destructive confirmation — double-tap warning pattern
    static func destructiveAction() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard isEnabled else { return }
            rigidImpact.impactOccurred(intensity: 0.5)
        }
    }

    /// Undo action — satisfying success with relief
    static func undoAction() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }

    /// Copy to clipboard — quick, light confirmation
    static func copyAction() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.5)
    }

    /// Scroll to bottom / anchor reached
    static func scrollAnchor() {
        guard isEnabled else { return }
        softImpact.impactOccurred(intensity: 0.3)
    }

    /// Error alert presentation — firm error tap
    static func errorAlert() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }

    // MARK: - CoreHaptics Patterns

    /// Settlement complete — professional double-pulse pattern
    static func settlementComplete() {
        guard isEnabled else { return }
        guard let engine = hapticEngine else {
            success()
            return
        }
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)

            let event1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity1, sharpness],
                relativeTime: 0
            )
            let event2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity2, sharpness],
                relativeTime: 0.12
            )

            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }

    /// Reminder sent — attention-getting pulse
    static func reminderSent() {
        guard isEnabled else { return }
        guard let engine = hapticEngine else {
            warning()
            return
        }
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)

            let event1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )
            let event2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0.08
            )
            let event3 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0.16
            )

            let pattern = try CHHapticPattern(events: [event1, event2, event3], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            warning()
        }
    }

    /// Transaction added — confident, weighty confirmation
    static func transactionAdded() {
        guard isEnabled else { return }
        guard let engine = hapticEngine else {
            success()
            return
        }
        do {
            let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)

            let event1 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity1, sharpness1],
                relativeTime: 0
            )
            let event2 = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity2, sharpness2],
                relativeTime: 0.15
            )

            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }
}
