//
//  HapticManager.swift
//  Swiss Coin
//
//  Centralized haptic feedback management for consistent user experience.
//

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
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Preparation
    
    /// Prepares haptic generators for immediate use (call on view appear)
    static func prepare() {
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
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
}