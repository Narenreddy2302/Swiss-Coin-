//
//  PrivacySecurityView.swift
//  Swiss Coin
//
//  Production-ready view for managing privacy and security settings.
//  Integrates with Supabase for persistent storage and sync.
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

            // Devices Section
            DevicesSection(viewModel: viewModel)

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
        .alert("Export Data", isPresented: $viewModel.showingDataExport) {
            Button("Export") {
                Task { await viewModel.exportData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data will be exported as a file that you can download. This may take a few minutes.")
        }
        .alert("Delete Account", isPresented: $viewModel.showingDeleteAccount) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is permanent and cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Sign Out All Devices", isPresented: $viewModel.showingSignOutAll) {
            Button("Sign Out") {
                Task { await viewModel.signOutAllOtherDevices() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All other devices will be signed out. They will need to log in again.")
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
                    Task { await viewModel.savePIN(pin) }
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
                    Task { await viewModel.disableBiometric() }
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
                    Task { await viewModel.disablePIN() }
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
                    Task { await viewModel.updateAutoLockTimeout(newValue) }
                }

                // Require for sensitive actions
                Toggle(isOn: $viewModel.requireAuthSensitive) {
                    Label("Require for Sensitive Actions", systemImage: "exclamationmark.shield.fill")
                }
                .onChange(of: viewModel.requireAuthSensitive) { _, newValue in
                    HapticManager.toggle()
                    Task { await viewModel.updateRequireAuthSensitive(newValue) }
                }
            }

            // Login History
            NavigationLink {
                LoginHistoryView()
            } label: {
                Label("Login History", systemImage: "clock.arrow.circlepath")
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

// MARK: - Devices Section

private struct DevicesSection: View {
    @ObservedObject var viewModel: PrivacySecurityViewModel

    var body: some View {
        Section {
            NavigationLink {
                ActiveSessionsView()
            } label: {
                HStack {
                    Label("Active Sessions", systemImage: "iphone.gen3")
                    Spacer()
                    if viewModel.activeSessionCount > 0 {
                        Text("\(viewModel.activeSessionCount)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }

            Button {
                HapticManager.tap()
                viewModel.showingSignOutAll = true
            } label: {
                Label("Sign Out All Other Devices", systemImage: "rectangle.portrait.and.arrow.forward")
                    .foregroundColor(AppColors.warning)
            }

            // Notify on new device
            Toggle(isOn: $viewModel.notifyOnNewDevice) {
                Label("Notify on New Device", systemImage: "bell.badge")
            }
            .onChange(of: viewModel.notifyOnNewDevice) { _, newValue in
                HapticManager.toggle()
                Task { await viewModel.updateNotifyOnNewDevice(newValue) }
            }
        } header: {
            Label("Devices", systemImage: "desktopcomputer")
                .font(AppTypography.subheadlineMedium())
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
                Task { await viewModel.updatePrivacySetting(\.showBalancesToContacts, newValue) }
            }

            Toggle(isOn: $viewModel.showLastSeen) {
                Label("Show Last Seen", systemImage: "clock")
            }
            .onChange(of: viewModel.showLastSeen) { _, newValue in
                HapticManager.toggle()
                Task { await viewModel.updatePrivacySetting(\.showLastSeen, newValue) }
            }

            Toggle(isOn: $viewModel.allowContactDiscovery) {
                Label("Allow Contact Discovery", systemImage: "person.badge.plus")
            }
            .onChange(of: viewModel.allowContactDiscovery) { _, newValue in
                HapticManager.toggle()
                Task { await viewModel.updatePrivacySetting(\.allowContactDiscovery, newValue) }
            }

            Toggle(isOn: $viewModel.showProfilePhoto) {
                Label("Show Profile Photo", systemImage: "photo.circle")
            }
            .onChange(of: viewModel.showProfilePhoto) { _, newValue in
                HapticManager.toggle()
                Task { await viewModel.updatePrivacySetting(\.showProfilePhoto, newValue) }
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
                Task { await viewModel.updatePrivacySetting(\.allowAnalytics, newValue) }
            }

            Toggle(isOn: $viewModel.allowCrashReports) {
                Label("Crash Reports", systemImage: "ant.fill")
            }
            .onChange(of: viewModel.allowCrashReports) { _, newValue in
                HapticManager.toggle()
                Task { await viewModel.updatePrivacySetting(\.allowCrashReports, newValue) }
            }

            NavigationLink {
                BlockedUsersView()
            } label: {
                HStack {
                    Label("Blocked Users", systemImage: "person.crop.circle.badge.xmark")
                    Spacer()
                    if viewModel.blockedUsersCount > 0 {
                        Text("\(viewModel.blockedUsersCount)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
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
            Button {
                HapticManager.tap()
                viewModel.showingDataExport = true
            } label: {
                HStack {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if viewModel.isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .disabled(viewModel.isExporting)

            Button(role: .destructive) {
                HapticManager.warning()
                viewModel.showingDeleteAccount = true
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
        } header: {
            Label("Account", systemImage: "person.crop.circle")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Export your data or permanently delete your account.")
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
    @Published var notifyOnNewDevice = true

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
    @Published var showingDataExport = false
    @Published var showingDeleteAccount = false
    @Published var showingSignOutAll = false
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var isLoading = false
    @Published var isExporting = false

    @Published var biometricErrorMessage = ""
    @Published var successMessage = ""
    @Published var errorMessage = ""
    @Published var biometricType: LABiometryType = .none
    @Published var activeSessionCount = 0
    @Published var blockedUsersCount = 0

    var onPINVerified: (() -> Void)?

    private let supabase = SupabaseManager.shared

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

        if CurrentUser.currentUserId != nil {
            Task {
                await loadFromSupabase()
                await loadCounts()
            }
        }
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
        allowAnalytics = UserDefaults.standard.object(forKey: "allow_analytics") as? Bool ?? true
    }

    private func loadFromSupabase() async {
        do {
            let securitySettings = try await supabase.getSecuritySettings()
            let privacySettings = try await supabase.getPrivacySettings()

            await MainActor.run {
                self.biometricEnabled = securitySettings.biometricEnabled
                self.pinEnabled = securitySettings.pinEnabled
                self.autoLockTimeout = securitySettings.autoLockTimeoutMinutes ?? 5
                self.requireAuthSensitive = securitySettings.requireAuthForSensitiveActions
                self.notifyOnNewDevice = securitySettings.notifyOnNewDevice

                self.showBalanceToContacts = privacySettings.showBalancesToContacts
                self.showLastSeen = privacySettings.showLastSeen
                self.allowContactDiscovery = privacySettings.allowContactDiscovery
                self.showProfilePhoto = privacySettings.showProfilePhoto
                self.allowAnalytics = privacySettings.allowAnalytics
                self.allowCrashReports = privacySettings.allowCrashReports

                // Save to local
                self.saveToLocal()
            }
        } catch {
            print("Failed to load settings from Supabase: \(error.localizedDescription)")
        }
    }

    private func loadCounts() async {
        do {
            let sessions = try await supabase.getActiveSessions()
            let blocked = try await supabase.getBlockedUsers()

            await MainActor.run {
                self.activeSessionCount = sessions.count
                self.blockedUsersCount = blocked.count
            }
        } catch {
            print("Failed to load counts: \(error.localizedDescription)")
        }
    }

    private func saveToLocal() {
        UserDefaults.standard.set(biometricEnabled, forKey: "biometric_enabled")
        UserDefaults.standard.set(pinEnabled, forKey: "pin_enabled")
        UserDefaults.standard.set(autoLockTimeout, forKey: "auto_lock_timeout")
        UserDefaults.standard.set(true, forKey: "auto_lock_set")
        UserDefaults.standard.set(requireAuthSensitive, forKey: "require_auth_sensitive")
        UserDefaults.standard.set(showBalanceToContacts, forKey: "show_balance_to_contacts")
        UserDefaults.standard.set(showLastSeen, forKey: "show_last_seen")
        UserDefaults.standard.set(allowContactDiscovery, forKey: "allow_contact_discovery")
        UserDefaults.standard.set(allowAnalytics, forKey: "allow_analytics")
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

                    if CurrentUser.currentUserId != nil {
                        Task {
                            try? await self.supabase.setBiometricEnabled(true, biometricType: self.biometricTypeString)
                        }
                    }
                } else {
                    self.biometricEnabled = false
                    self.biometricErrorMessage = authError?.localizedDescription ?? "Authentication failed"
                    self.showingBiometricError = true
                }
            }
        }
    }

    func disableBiometric() async {
        biometricEnabled = false
        UserDefaults.standard.set(false, forKey: "biometric_enabled")

        if CurrentUser.currentUserId != nil {
            try? await supabase.setBiometricEnabled(false, biometricType: nil)
        }
    }

    private var biometricTypeString: String {
        switch biometricType {
        case .faceID: return "face_id"
        case .touchID: return "touch_id"
        case .opticID: return "optic_id"
        default: return "unknown"
        }
    }

    // MARK: - PIN

    func savePIN(_ pin: String) async {
        let pinHash = hashPIN(pin)

        // Save locally
        KeychainHelper.save(key: "user_pin_hash", value: pinHash)
        pinEnabled = true
        UserDefaults.standard.set(true, forKey: "pin_enabled")

        // Save to Supabase
        if CurrentUser.currentUserId != nil {
            do {
                try await supabase.setPIN(pinHash: pinHash)
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    func disablePIN() async {
        KeychainHelper.delete(key: "user_pin_hash")
        pinEnabled = false
        UserDefaults.standard.set(false, forKey: "pin_enabled")

        if CurrentUser.currentUserId != nil {
            try? await supabase.disablePIN()
        }
    }

    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Settings Updates

    func updateAutoLockTimeout(_ minutes: Int) async {
        autoLockTimeout = minutes
        UserDefaults.standard.set(minutes, forKey: "auto_lock_timeout")

        if CurrentUser.currentUserId != nil {
            try? await supabase.setAutoLockTimeout(minutes)
        }
    }

    func updateRequireAuthSensitive(_ required: Bool) async {
        requireAuthSensitive = required
        UserDefaults.standard.set(required, forKey: "require_auth_sensitive")

        if CurrentUser.currentUserId != nil {
            try? await supabase.setRequireAuthForSensitiveActions(required)
        }
    }

    func updateNotifyOnNewDevice(_ notify: Bool) async {
        notifyOnNewDevice = notify

        if CurrentUser.currentUserId != nil {
            var update = SecuritySettingsUpdate()
            update.biometricEnabled = nil
            _ = try? await supabase.updateSecuritySettings(SecuritySettingsUpdate())
        }
    }

    func updatePrivacySetting<T>(_ keyPath: WritableKeyPath<PrivacySettingsUpdate, T?>, _ value: T) async {
        var update = PrivacySettingsUpdate()
        update[keyPath: keyPath] = value
        saveToLocal()

        if CurrentUser.currentUserId != nil {
            try? await supabase.updatePrivacySettings(update)
        }
    }

    // MARK: - Session Management

    func signOutAllOtherDevices() async {
        do {
            let count = try await supabase.terminateAllOtherSessionsEnhanced()
            activeSessionCount = 1 // Only current session remains
            successMessage = "\(count) device(s) signed out successfully"
            showingSuccess = true
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
    }

    // MARK: - Data Export & Account Deletion

    func exportData() async {
        isExporting = true

        do {
            let exportUrl = try await supabase.requestDataExport()
            isExporting = false

            // Open URL to download
            if let url = URL(string: exportUrl) {
                await UIApplication.shared.open(url)
            }

            successMessage = "Your data export is ready for download"
            showingSuccess = true
            HapticManager.success()
        } catch {
            isExporting = false
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
    }

    func deleteAccount() async {
        do {
            try await supabase.requestAccountDeletion()
            HapticManager.success()
            // Sign out after deletion request
            await supabase.signOut()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
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

// MARK: - Active Sessions View

struct ActiveSessionsView: View {
    @StateObject private var viewModel = ActiveSessionsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.sessions.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)

                    Text("No active sessions")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.sessions) { session in
                    SessionRowView(
                        session: session,
                        onRevoke: {
                            Task { await viewModel.revokeSession(session) }
                        },
                        onToggleTrust: {
                            Task { await viewModel.toggleTrust(session) }
                        }
                    )
                }
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadSessions()
        }
        .onAppear {
            Task { await viewModel.loadSessions() }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

@MainActor
class ActiveSessionsViewModel: ObservableObject {
    @Published var sessions: [UserSessionInfo] = []
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""

    private let supabase = SupabaseManager.shared

    func loadSessions() async {
        isLoading = true

        do {
            sessions = try await supabase.getActiveSessions()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isLoading = false
    }

    func revokeSession(_ session: UserSessionInfo) async {
        do {
            try await supabase.terminateSession(sessionId: session.id)
            sessions.removeAll { $0.id == session.id }
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
    }

    func toggleTrust(_ session: UserSessionInfo) async {
        do {
            try await supabase.setDeviceTrusted(session.id, trusted: !session.isCurrent)
            await loadSessions()
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct SessionRowView: View {
    let session: UserSessionInfo
    let onRevoke: () -> Void
    let onToggleTrust: () -> Void

    private var deviceIcon: String {
        switch session.deviceType?.lowercased() {
        case "iphone": return "iphone.gen3"
        case "ipad": return "ipad.gen2"
        case "android": return "candybarphone"
        case "web": return "globe"
        default: return "desktopcomputer"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: deviceIcon)
                .font(.system(size: 28))
                .foregroundColor(AppColors.accent)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.deviceName ?? "Unknown Device")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    if session.isCurrent {
                        Text("This device")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let location = session.location, !location.isEmpty {
                    Text(location)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("Last active: \(session.lastActiveAt, style: .relative)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            if !session.isCurrent {
                Button {
                    HapticManager.warning()
                    onRevoke()
                } label: {
                    Text("Revoke")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.negative)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Login History View

struct LoginHistoryView: View {
    @StateObject private var viewModel = LoginHistoryViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.entries.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)

                    Text("No login history")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.entries) { entry in
                    LoginHistoryRowView(entry: entry)
                }
            }
        }
        .navigationTitle("Login History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.loadHistory() }
        }
    }
}

@MainActor
class LoginHistoryViewModel: ObservableObject {
    @Published var entries: [LoginHistoryEntry] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared

    func loadHistory() async {
        isLoading = true

        do {
            entries = try await supabase.getLoginHistory()
        } catch {
            print("Failed to load login history: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

struct LoginHistoryRowView: View {
    let entry: LoginHistoryEntry

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(entry.success ? AppColors.positive : AppColors.negative)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.success ? "Successful login" : "Failed login")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    if entry.isSuspicious {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                    }
                }

                if let device = entry.deviceName {
                    Text(device)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                if let city = entry.locationCity, let country = entry.locationCountry {
                    Text("\(city), \(country)")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Text(entry.attemptedAt, style: .relative)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Blocked Users View

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.blockedUsers.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.positive)

                    Text("No blocked users")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Users you block won't be able to send you messages or add you to groups.")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.blockedUsers) { user in
                    HStack(spacing: Spacing.md) {
                        if let avatarUrl = user.blocked?.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(AppColors.textSecondary.opacity(0.3))
                            }
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(AppColors.textSecondary.opacity(0.3))
                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                .overlay(
                                    Text(String((user.blocked?.displayName ?? "?").prefix(2)).uppercased())
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.blocked?.displayName ?? "Unknown User")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Blocked \(user.createdAt, style: .relative)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Button("Unblock") {
                            Task { await viewModel.unblockUser(user) }
                        }
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.loadBlockedUsers() }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

@MainActor
class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUserInfo] = []
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""

    private let supabase = SupabaseManager.shared

    func loadBlockedUsers() async {
        isLoading = true

        do {
            blockedUsers = try await supabase.getBlockedUsers()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isLoading = false
    }

    func unblockUser(_ user: BlockedUserInfo) async {
        do {
            try await supabase.unblockUser(userId: user.blockedId)
            blockedUsers.removeAll { $0.id == user.id }
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            HapticManager.error()
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySecurityView()
    }
}
