//
//  PrivacySecurityView.swift
//  Swiss Coin
//
//  View for managing privacy and security settings.
//  All settings are stored locally via UserDefaults and Keychain.
//

import Combine
import CryptoKit
import LocalAuthentication
import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PrivacySecurityViewModel()

    var body: some View {
        Form {
            // Security Section
            SecuritySection(viewModel: viewModel)

            // Privacy Section
            PrivacySection(viewModel: viewModel)

            // Data Section
            DataSection(viewModel: viewModel)

            // Account Actions Section
            AccountActionsSection(viewModel: viewModel)
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSettings()
        }
        .alert("Biometric Error", isPresented: $viewModel.showingBiometricError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(viewModel.biometricErrorMessage)
        }
        .alert("Clear All Data", isPresented: $viewModel.showingDeleteAccount) {
            Button("Clear Data", role: .destructive) {
                viewModel.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all local data and sign you out. This action cannot be undone.")
        }
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK", role: .cancel) {
                HapticManager.success()
            }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $viewModel.showingPINSetup) {
            PINSetupView(
                onComplete: { pin in
                    viewModel.savePIN(pin)
                },
                onCancel: {
                    viewModel.pinEnabled = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingPINVerify) {
            PINVerifyView(
                onVerified: {
                    viewModel.onPINVerified?()
                },
                onCancel: {
                    viewModel.showingPINVerify = false
                }
            )
        }
    }
}

// MARK: - Security Section

private struct SecuritySection: View {
    @ObservedObject var viewModel: PrivacySecurityViewModel

    var body: some View {
        Section {
            // Biometric Toggle
            Toggle(isOn: $viewModel.biometricEnabled) {
                Label(viewModel.biometricLabel, systemImage: viewModel.biometricIcon)
            }
            .onChange(of: viewModel.biometricEnabled) { _, newValue in
                HapticManager.toggle()
                if newValue {
                    viewModel.enableBiometric()
                } else {
                    viewModel.disableBiometric()
                }
            }
            .disabled(viewModel.biometricType == .none)

            // PIN Toggle
            Toggle(isOn: $viewModel.pinEnabled) {
                Label("PIN Lock", systemImage: "lock.fill")
            }
            .onChange(of: viewModel.pinEnabled) { _, newValue in
                HapticManager.toggle()
                if newValue {
                    viewModel.showingPINSetup = true
                } else {
                    viewModel.disablePIN()
                }
            }

            // Auto-Lock Timeout
            if viewModel.biometricEnabled || viewModel.pinEnabled {
                Picker(selection: $viewModel.autoLockTimeout) {
                    Text("Immediately").tag(0)
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                } label: {
                    Label("Auto-Lock", systemImage: "timer")
                }
                .onChange(of: viewModel.autoLockTimeout) { _, newValue in
                    HapticManager.selectionChanged()
                    viewModel.saveAutoLockTimeout(newValue)
                }

                // Require for sensitive actions
                Toggle(isOn: $viewModel.requireAuthSensitive) {
                    Label("Require for Sensitive Actions", systemImage: "exclamationmark.shield.fill")
                }
                .onChange(of: viewModel.requireAuthSensitive) { _, newValue in
                    HapticManager.toggle()
                    UserDefaults.standard.set(newValue, forKey: "require_auth_sensitive")
                }
            }
        } header: {
            Label("Security", systemImage: "lock.shield.fill")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Protect the app with biometric authentication or a 6-digit PIN code.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - Privacy Section

private struct PrivacySection: View {
    @ObservedObject var viewModel: PrivacySecurityViewModel

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.showBalanceToContacts) {
                Label("Show Balance to Contacts", systemImage: "dollarsign.circle")
            }
            .onChange(of: viewModel.showBalanceToContacts) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "show_balance_to_contacts")
            }

            Toggle(isOn: $viewModel.showLastSeen) {
                Label("Show Last Seen", systemImage: "clock")
            }
            .onChange(of: viewModel.showLastSeen) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "show_last_seen")
            }

            Toggle(isOn: $viewModel.allowContactDiscovery) {
                Label("Allow Contact Discovery", systemImage: "person.badge.plus")
            }
            .onChange(of: viewModel.allowContactDiscovery) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "allow_contact_discovery")
            }

            Toggle(isOn: $viewModel.showProfilePhoto) {
                Label("Show Profile Photo", systemImage: "photo.circle")
            }
            .onChange(of: viewModel.showProfilePhoto) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "show_profile_photo")
            }
        } header: {
            Label("Privacy", systemImage: "hand.raised.fill")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Control what information is visible to your contacts.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - Data Section

private struct DataSection: View {
    @ObservedObject var viewModel: PrivacySecurityViewModel

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.allowAnalytics) {
                Label("Analytics", systemImage: "chart.bar.fill")
            }
            .onChange(of: viewModel.allowAnalytics) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "allow_analytics")
            }

            Toggle(isOn: $viewModel.allowCrashReports) {
                Label("Crash Reports", systemImage: "ant.fill")
            }
            .onChange(of: viewModel.allowCrashReports) { _, newValue in
                HapticManager.toggle()
                UserDefaults.standard.set(newValue, forKey: "allow_crash_reports")
            }
        } header: {
            Label("Data", systemImage: "externaldrive.fill")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Help improve the app by sharing anonymous usage data.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - Account Actions Section

private struct AccountActionsSection: View {
    @ObservedObject var viewModel: PrivacySecurityViewModel

    var body: some View {
        Section {
            Button(role: .destructive) {
                HapticManager.warning()
                viewModel.showingDeleteAccount = true
            } label: {
                Label("Clear All Data & Sign Out", systemImage: "trash")
            }
        } header: {
            Label("Account", systemImage: "person.crop.circle")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Remove all local data and return to the welcome screen.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - View Model

@MainActor
class PrivacySecurityViewModel: ObservableObject {
    // Security Settings
    @Published var biometricEnabled = false
    @Published var pinEnabled = false
    @Published var autoLockTimeout = 5
    @Published var requireAuthSensitive = true

    // Privacy Settings
    @Published var showBalanceToContacts = false
    @Published var showLastSeen = true
    @Published var allowContactDiscovery = true
    @Published var showProfilePhoto = true
    @Published var allowAnalytics = true
    @Published var allowCrashReports = true

    // UI State
    @Published var showingPINSetup = false
    @Published var showingPINVerify = false
    @Published var showingBiometricError = false
    @Published var showingDeleteAccount = false
    @Published var showingSuccess = false
    @Published var showingError = false

    @Published var biometricErrorMessage = ""
    @Published var successMessage = ""
    @Published var errorMessage = ""
    @Published var biometricType: LABiometryType = .none

    var onPINVerified: (() -> Void)?

    // MARK: - Computed Properties

    var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometric"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    // MARK: - Load Settings

    func loadSettings() {
        checkBiometricType()
        loadFromLocal()
    }

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    private func loadFromLocal() {
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
        pinEnabled = UserDefaults.standard.bool(forKey: "pin_enabled")
        autoLockTimeout = UserDefaults.standard.integer(forKey: "auto_lock_timeout")
        if autoLockTimeout == 0 && !UserDefaults.standard.bool(forKey: "auto_lock_set") {
            autoLockTimeout = 5
        }
        requireAuthSensitive = UserDefaults.standard.object(forKey: "require_auth_sensitive") as? Bool ?? true
        showBalanceToContacts = UserDefaults.standard.bool(forKey: "show_balance_to_contacts")
        showLastSeen = UserDefaults.standard.object(forKey: "show_last_seen") as? Bool ?? true
        allowContactDiscovery = UserDefaults.standard.object(forKey: "allow_contact_discovery") as? Bool ?? true
        showProfilePhoto = UserDefaults.standard.object(forKey: "show_profile_photo") as? Bool ?? true
        allowAnalytics = UserDefaults.standard.object(forKey: "allow_analytics") as? Bool ?? true
        allowCrashReports = UserDefaults.standard.object(forKey: "allow_crash_reports") as? Bool ?? true
    }

    // MARK: - Biometric

    func enableBiometric() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricErrorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            showingBiometricError = true
            biometricEnabled = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Enable biometric authentication for Swiss Coin"
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    HapticManager.success()
                    self.biometricEnabled = true
                    UserDefaults.standard.set(true, forKey: "biometric_enabled")
                } else {
                    self.biometricEnabled = false
                    self.biometricErrorMessage = authError?.localizedDescription ?? "Authentication failed"
                    self.showingBiometricError = true
                }
            }
        }
    }

    func disableBiometric() {
        biometricEnabled = false
        UserDefaults.standard.set(false, forKey: "biometric_enabled")
    }

    // MARK: - PIN

    func savePIN(_ pin: String) {
        let pinHash = hashPIN(pin)

        // Save locally via Keychain
        KeychainHelper.save(key: "user_pin_hash", value: pinHash)
        pinEnabled = true
        UserDefaults.standard.set(true, forKey: "pin_enabled")
        HapticManager.success()
    }

    func disablePIN() {
        KeychainHelper.delete(key: "user_pin_hash")
        pinEnabled = false
        UserDefaults.standard.set(false, forKey: "pin_enabled")
    }

    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Settings Updates

    func saveAutoLockTimeout(_ minutes: Int) {
        autoLockTimeout = minutes
        UserDefaults.standard.set(minutes, forKey: "auto_lock_timeout")
        UserDefaults.standard.set(true, forKey: "auto_lock_set")
    }

    // MARK: - Clear Data & Sign Out

    func clearAllData() {
        // Clear Keychain
        KeychainHelper.delete(key: "user_pin_hash")
        KeychainHelper.delete(key: "swiss_coin_access_token")
        KeychainHelper.delete(key: "swiss_coin_refresh_token")
        KeychainHelper.delete(key: "swiss_coin_user_id")

        // Reset user
        CurrentUser.reset()

        // Sign out
        AuthManager.shared.signOut()

        HapticManager.success()
    }
}

// MARK: - PIN Setup View

struct PINSetupView: View {
    @Environment(\.dismiss) var dismiss
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: PINSetupStep = .enter
    @State private var errorMessage = ""
    @FocusState private var isFocused: Bool

    enum PINSetupStep {
        case enter, confirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.accent)

                Text(step == .enter ? "Create a PIN" : "Confirm your PIN")
                    .font(AppTypography.title2())
                    .foregroundColor(AppColors.textPrimary)

                Text(step == .enter ? "Enter a 6-digit PIN" : "Re-enter your PIN to confirm")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)

                // PIN Dots Display
                HStack(spacing: Spacing.md) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index < currentPIN.count ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.vertical, Spacing.lg)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.negative)
                }

                // Hidden TextField for keyboard
                TextField("", text: step == .enter ? $pin : $confirmPin)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: currentPIN) { _, newValue in
                        handlePINChange(newValue)
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Set PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private var currentPIN: String {
        step == .enter ? pin : confirmPin
    }

    private func handlePINChange(_ newValue: String) {
        // Only allow digits
        let filtered = String(newValue.filter { $0.isNumber }.prefix(6))

        if step == .enter {
            pin = filtered
        } else {
            confirmPin = filtered
        }

        if filtered.count == 6 {
            HapticManager.selectionChanged()

            if step == .enter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    step = .confirm
                    isFocused = true
                }
            } else {
                if confirmPin == pin {
                    HapticManager.success()
                    onComplete(pin)
                    dismiss()
                } else {
                    HapticManager.error()
                    errorMessage = "PINs don't match. Try again."
                    confirmPin = ""
                    step = .enter
                    pin = ""
                }
            }
        }
    }
}

// MARK: - PIN Verify View

struct PINVerifyView: View {
    @Environment(\.dismiss) var dismiss
    let onVerified: () -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var attemptsRemaining = 5
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.accent)

                Text("Enter your PIN")
                    .font(AppTypography.title2())
                    .foregroundColor(AppColors.textPrimary)

                // PIN Dots Display
                HStack(spacing: Spacing.md) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index < pin.count ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.vertical, Spacing.lg)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.negative)
                }

                if attemptsRemaining < 5 {
                    Text("\(attemptsRemaining) attempts remaining")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.warning)
                }

                // Hidden TextField for keyboard
                TextField("", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: pin) { _, newValue in
                        handlePINChange(newValue)
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Verify PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func handlePINChange(_ newValue: String) {
        let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
        pin = filtered

        if filtered.count == 6 {
            verifyPIN(filtered)
        }
    }

    private func verifyPIN(_ enteredPIN: String) {
        // Hash and compare
        let data = Data(enteredPIN.utf8)
        let hash = SHA256.hash(data: data)
        let enteredHash = hash.compactMap { String(format: "%02x", $0) }.joined()

        if let storedHash = KeychainHelper.read(key: "user_pin_hash"),
           enteredHash == storedHash {
            HapticManager.success()
            onVerified()
            dismiss()
        } else {
            HapticManager.error()
            attemptsRemaining -= 1
            pin = ""

            if attemptsRemaining <= 0 {
                errorMessage = "Too many attempts. Please try again later."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onCancel()
                    dismiss()
                }
            } else {
                errorMessage = "Incorrect PIN"
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySecurityView()
    }
}
