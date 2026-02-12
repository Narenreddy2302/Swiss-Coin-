//
//  AppLockManager.swift
//  Swiss Coin
//
//  Manages app-level lock state, auto-lock timing, and background data preloading.
//  Modeled after Cash App / Revolut: gates the UI behind PIN or biometric,
//  while pre-fetching data so the main screen is instantly ready on unlock.
//

import Combine
import CryptoKit
import LocalAuthentication
import SwiftUI

// MARK: - Lock State

enum AppLockState: Equatable {
    case locked
    case unlocked
    case unlocking // Transitional state for smooth animation
}

// MARK: - App Lock Manager

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    // MARK: - Published State

    @Published private(set) var lockState: AppLockState = .locked
    @Published private(set) var isPreloadComplete = false

    // MARK: - Security Configuration (read from UserDefaults)

    var isPINEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pin_enabled")
    }

    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometric_enabled")
    }

    var isSecurityEnabled: Bool {
        isPINEnabled || isBiometricEnabled
    }

    var autoLockTimeoutMinutes: Int {
        let timeout = UserDefaults.standard.integer(forKey: "auto_lock_timeout")
        return timeout > 0 ? timeout : 5
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType
        }
        return .none
    }

    // MARK: - Internal State

    /// Timestamp when app last entered background. Used for auto-lock timeout.
    private var backgroundTimestamp: Date?

    /// Tracks whether we've done the initial security check on launch.
    private var hasPerformedInitialCheck = false

    // MARK: - Init

    private init() {}

    // MARK: - Initial Lock Check

    /// Called once on app launch. If no security is configured, skip straight to unlocked.
    func performInitialLockCheck() {
        guard !hasPerformedInitialCheck else { return }
        hasPerformedInitialCheck = true

        if isSecurityEnabled {
            lockState = .locked
            // Start preloading data immediately behind the lock screen
            startBackgroundPreload()
        } else {
            lockState = .unlocked
            isPreloadComplete = true
        }
    }

    // MARK: - PIN Verification

    /// Verifies a 6-digit PIN against the stored SHA-256 hash in Keychain.
    /// Returns true if the PIN is correct.
    func verifyPIN(_ pin: String) -> Bool {
        guard let storedHash = KeychainHelper.read(key: "user_pin_hash") else {
            return false
        }
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        let pinHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        return pinHash == storedHash
    }

    // MARK: - Biometric Authentication

    /// Attempts biometric authentication (Face ID / Touch ID).
    /// Calls the completion handler on the main thread.
    func authenticateWithBiometric() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let reason: String
            switch context.biometryType {
            case .faceID:
                reason = "Unlock Swiss Coin with Face ID"
            case .touchID:
                reason = "Unlock Swiss Coin with Touch ID"
            default:
                reason = "Unlock Swiss Coin"
            }

            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    // MARK: - Unlock

    /// Transitions from locked to unlocked with a brief unlocking state for animation.
    func unlock() {
        guard lockState != .unlocked else { return }
        lockState = .unlocking
        HapticManager.success()

        // Brief delay for the unlock animation to play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.lockState = .unlocked
        }
    }

    // MARK: - Scene Phase / Auto-Lock

    /// Called when the app enters the background.
    func appDidEnterBackground() {
        backgroundTimestamp = Date()
    }

    /// Called when the app returns to the foreground.
    /// Re-locks the app if the auto-lock timeout has elapsed.
    func appDidEnterForeground() {
        guard isSecurityEnabled else { return }
        guard lockState == .unlocked else { return }

        if let timestamp = backgroundTimestamp {
            let elapsed = Date().timeIntervalSince(timestamp)
            let timeout = TimeInterval(autoLockTimeoutMinutes * 60)
            if elapsed >= timeout {
                lockState = .locked
                isPreloadComplete = true // Data is already loaded from before
            }
        }

        backgroundTimestamp = nil
    }

    // MARK: - Background Preload

    /// Kicks off data preloading so that by the time the user unlocks,
    /// Core Data caches are warm and the home screen renders instantly.
    private func startBackgroundPreload() {
        isPreloadComplete = false

        Task.detached(priority: .userInitiated) {
            let container = PersistenceController.shared.container
            let bgContext = container.newBackgroundContext()

            await bgContext.perform {
                // Warm up Core Data caches by executing the same fetches
                // that HomeView and MainTabView will need.

                // 1. Recent transactions
                let txRequest: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
                txRequest.predicate = NSPredicate(format: "title != nil AND title.length > 0")
                txRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
                txRequest.fetchLimit = 5
                _ = try? bgContext.fetch(txRequest)

                // 2. People (for balance calculations)
                let peopleRequest: NSFetchRequest<Person> = Person.fetchRequest()
                peopleRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
                peopleRequest.fetchBatchSize = 20
                _ = try? bgContext.fetch(peopleRequest)

                // 3. Active subscriptions
                let subRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
                subRequest.predicate = NSPredicate(format: "isActive == YES")
                subRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.name, ascending: true)]
                _ = try? bgContext.fetch(subRequest)

                // 4. Unread reminders (for badge counts)
                let reminderRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
                reminderRequest.predicate = NSPredicate(format: "isRead == NO")
                reminderRequest.fetchLimit = 99
                _ = try? bgContext.fetch(reminderRequest)
            }

            await MainActor.run {
                self.isPreloadComplete = true
            }
        }
    }
}
