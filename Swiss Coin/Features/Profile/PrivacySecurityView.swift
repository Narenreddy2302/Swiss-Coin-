//
//  PrivacySecurityView.swift
//  Swiss Coin
//
//  View for managing privacy and security settings.
//

import LocalAuthentication
import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) var dismiss

    // Security Settings
    @AppStorage("biometric_enabled") private var biometricEnabled = false
    @AppStorage("pin_enabled") private var pinEnabled = false
    @AppStorage("auto_lock_timeout") private var autoLockTimeout = 5
    @AppStorage("require_auth_sensitive") private var requireAuthSensitive = true

    // Privacy Settings
    @AppStorage("show_balance_to_contacts") private var showBalanceToContacts = false
    @AppStorage("show_last_seen") private var showLastSeen = true
    @AppStorage("allow_contact_discovery") private var allowContactDiscovery = true
    @AppStorage("allow_analytics") private var allowAnalytics = true

    @State private var showingPINSetup = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""
    @State private var biometricType: LABiometryType = .none
    @State private var showingDataExport = false
    @State private var showingDeleteAccount = false

    var body: some View {
        Form {
            // Biometric Authentication
            Section {
                Toggle(isOn: $biometricEnabled) {
                    Label(biometricLabel, systemImage: biometricIcon)
                }
                .onChange(of: biometricEnabled) { _, newValue in
                    HapticManager.toggle()
                    if newValue {
                        authenticateBiometric()
                    }
                }

                Toggle(isOn: $pinEnabled) {
                    Label("PIN Lock", systemImage: "lock.fill")
                }
                .onChange(of: pinEnabled) { _, newValue in
                    HapticManager.toggle()
                    if newValue {
                        showingPINSetup = true
                    }
                }

                if biometricEnabled || pinEnabled {
                    Picker("Auto-Lock", selection: $autoLockTimeout) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("Never").tag(0)
                    }
                }

                Toggle("Require for sensitive actions", isOn: $requireAuthSensitive)
                    .onChange(of: requireAuthSensitive) { _, _ in HapticManager.toggle() }
            } header: {
                Label("Security", systemImage: "lock.shield.fill")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Protect the app with biometric authentication or a PIN code.")
                    .font(AppTypography.caption())
            }

            // Active Sessions
            Section {
                NavigationLink {
                    ActiveSessionsView()
                } label: {
                    Label("Active Sessions", systemImage: "iphone.gen3")
                }

                Button {
                    HapticManager.buttonPress()
                    // Sign out all other devices
                } label: {
                    Label("Sign Out All Other Devices", systemImage: "rectangle.portrait.and.arrow.forward")
                        .foregroundColor(AppColors.warning)
                }
            } header: {
                Label("Devices", systemImage: "desktopcomputer")
                    .font(AppTypography.subheadlineMedium())
            }

            // Privacy Settings
            Section {
                Toggle("Show balance to contacts", isOn: $showBalanceToContacts)
                    .onChange(of: showBalanceToContacts) { _, _ in HapticManager.toggle() }

                Toggle("Show last seen", isOn: $showLastSeen)
                    .onChange(of: showLastSeen) { _, _ in HapticManager.toggle() }

                Toggle("Allow contact discovery", isOn: $allowContactDiscovery)
                    .onChange(of: allowContactDiscovery) { _, _ in HapticManager.toggle() }
            } header: {
                Label("Privacy", systemImage: "hand.raised.fill")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Control what information is visible to your contacts.")
                    .font(AppTypography.caption())
            }

            // Data & Analytics
            Section {
                Toggle("Analytics", isOn: $allowAnalytics)
                    .onChange(of: allowAnalytics) { _, _ in HapticManager.toggle() }

                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("Blocked Users", systemImage: "person.crop.circle.badge.xmark")
                }
            } header: {
                Label("Data", systemImage: "chart.bar.fill")
                    .font(AppTypography.subheadlineMedium())
            }

            // Account Actions
            Section {
                Button {
                    HapticManager.tap()
                    showingDataExport = true
                } label: {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    HapticManager.tap()
                    showingDeleteAccount = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            } header: {
                Label("Account", systemImage: "person.crop.circle")
                    .font(AppTypography.subheadlineMedium())
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkBiometricType()
        }
        .alert("Biometric Error", isPresented: $showingBiometricError) {
            Button("OK", role: .cancel) {
                biometricEnabled = false
            }
        } message: {
            Text(biometricErrorMessage)
        }
        .alert("Export Data", isPresented: $showingDataExport) {
            Button("Export", role: .none) {
                exportData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data will be exported as a file that you can download.")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is permanent and cannot be undone. All your data will be deleted.")
        }
    }

    // MARK: - Computed Properties

    private var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometric"
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    // MARK: - Functions

    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }

    private func authenticateBiometric() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricErrorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            showingBiometricError = true
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric authentication") { success, authError in
            DispatchQueue.main.async {
                if success {
                    HapticManager.success()
                } else {
                    biometricEnabled = false
                    biometricErrorMessage = authError?.localizedDescription ?? "Authentication failed"
                    showingBiometricError = true
                }
            }
        }
    }

    private func exportData() {
        HapticManager.success()
        // In production: Call Supabase function to generate data export
    }

    private func deleteAccount() {
        HapticManager.warning()
        // In production: Call Supabase function to delete account
    }
}

// MARK: - Active Sessions View

struct ActiveSessionsView: View {
    // In production, fetch from user_sessions table
    @State private var sessions: [SessionInfo] = [
        SessionInfo(id: UUID(), deviceName: "iPhone 15 Pro", deviceType: "iphone", location: "San Francisco, US", lastActive: Date(), isCurrent: true),
        SessionInfo(id: UUID(), deviceName: "iPad Air", deviceType: "ipad", location: "San Francisco, US", lastActive: Date().addingTimeInterval(-3600), isCurrent: false)
    ]

    var body: some View {
        List {
            ForEach(sessions) { session in
                SessionRow(session: session, onRevoke: {
                    revokeSession(session)
                })
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func revokeSession(_ session: SessionInfo) {
        HapticManager.warning()
        sessions.removeAll { $0.id == session.id }
    }
}

struct SessionInfo: Identifiable {
    let id: UUID
    let deviceName: String
    let deviceType: String
    let location: String
    let lastActive: Date
    let isCurrent: Bool
}

struct SessionRow: View {
    let session: SessionInfo
    let onRevoke: () -> Void

    private var deviceIcon: String {
        switch session.deviceType {
        case "iphone": return "iphone.gen3"
        case "ipad": return "ipad.gen2"
        default: return "desktopcomputer"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: deviceIcon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.deviceName)
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

                Text(session.location)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text("Last active: \(session.lastActive, style: .relative)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            if !session.isCurrent {
                Button {
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

// MARK: - Blocked Users View

struct BlockedUsersView: View {
    @State private var blockedUsers: [Person] = []

    var body: some View {
        List {
            if blockedUsers.isEmpty {
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
                ForEach(blockedUsers) { user in
                    HStack(spacing: Spacing.md) {
                        Circle()
                            .fill(Color(hex: user.colorHex ?? "#808080").opacity(0.3))
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay(
                                Text(user.initials)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: user.colorHex ?? "#808080"))
                            )

                        Text(user.displayName)
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Button("Unblock") {
                            unblockUser(user)
                        }
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func unblockUser(_ user: Person) {
        HapticManager.success()
        blockedUsers.removeAll { $0.id == user.id }
    }
}
