//
//  HapticManager.swift
//  Swiss Coin
//
//  Centralized haptic feedback management for consistent user experience.
//

import UIKit

/// Manages haptic feedback throughout the app
final class HapticManager {
    
    // MARK: - Shared Generators
    
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Preparation
    
    /// Prepares haptic generators for immediate use (call on view appear)
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Light tap feedback for secondary actions
    static func lightTap() {
        lightImpact.impactOccurred()
    }
    
    /// Standard tap feedback for primary actions  
    static func tap() {
        mediumImpact.impactOccurred()
    }
    
    /// Heavy tap feedback for important actions
    static func heavyTap() {
        heavyImpact.impactOccurred()
    }
    
    // MARK: - Selection Feedback
    
    /// Selection change feedback for pickers, toggles, segments
    static func selectionChanged() {
        selectionFeedback.selectionChanged()
    }
    
    /// Toggle state change feedback
    static func toggle() {
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    /// Success feedback for completed actions
    static func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning feedback for reversible errors
    static func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error feedback for failed actions
    static func error() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Semantic Actions
    
    /// Feedback for save operations
    static func save() {
        mediumImpact.impactOccurred()
    }
    
    /// Feedback for cancel operations
    static func cancel() {
        lightImpact.impactOccurred()
    }
    
    /// Feedback for delete operations
    static func delete() {
        heavyImpact.impactOccurred()
    }
}