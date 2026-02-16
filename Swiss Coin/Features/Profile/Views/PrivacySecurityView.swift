//
//  PrivacySecurityView.swift
//  Swiss Coin
//
//  Simplified privacy and security settings with card-based design.
//

import Combine
import CryptoKit
import LocalAuthentication
import SwiftUI

@MainActor
class PrivacySecurityViewModel: ObservableObject {
    @Published var biometricEnabled = false
    @Published var pinEnabled = false
    @Published var autoLockTimeout = 5
    @Published var showBalanceToContacts = false
    @Published var showLastSeen = true
    @Published var allowAnalytics = true

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

    var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
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

    func loadSettings() {
        checkBiometricType()
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
        pinEnabled = UserDefaults.standard.bool(forKey: "pin_enabled")
        autoLockTimeout = UserDefaults.standard.integer(forKey: "auto_lock_timeout")
        if autoLockTimeout == 0 { autoLockTimeout = 5 }
        showBalanceToContacts = UserDefaults.standard.bool(forKey: "show_balance_to_contacts")
        showLastSeen = UserDefaults.standard.object(forKey: "show_last_seen") as? Bool ?? true
        allowAnalytics = UserDefaults.standard.object(forKey: "allow_analytics") as? Bool ?? true
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

    func enableBiometric() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricErrorMessage = error?.localizedDescription ?? "Biometric not available"
            showingBiometricError = true
            biometricEnabled = false
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric authentication") { success, authError in
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

    func savePIN(_ pin: String) {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        let pinHash = hash.compactMap { String(format: "%02x", $0) }.joined()
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

    func clearAllData() {
        KeychainHelper.delete(key: "user_pin_hash")
        KeychainHelper.delete(key: "swiss_coin_access_token")
        KeychainHelper.delete(key: "swiss_coin_refresh_token")
        CurrentUser.reset()
        AuthManager.shared.signOut()
        HapticManager.success()
    }
}

struct PrivacySecurityView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PrivacySecurityViewModel()

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Security Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Security")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            // Biometric Toggle
                            if viewModel.biometricType != .none {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: viewModel.biometricIcon)
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: IconSize.category)

                                    Text(viewModel.biometricLabel)
                                        .font(AppTypography.bodyLarge())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Toggle("", isOn: $viewModel.biometricEnabled)
                                        .labelsHidden()
                                        .onChange(of: viewModel.biometricEnabled) { _, newValue in
                                            HapticManager.toggle()
                                            if newValue {
                                                viewModel.enableBiometric()
                                            } else {
                                                viewModel.disableBiometric()
                                            }
                                        }
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)

                                Divider()
                                    .padding(.leading, Spacing.rowDividerInset)
                            }

                            // PIN Toggle
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: IconSize.category)

                                Text("PIN Lock")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Toggle("", isOn: $viewModel.pinEnabled)
                                    .labelsHidden()
                                    .onChange(of: viewModel.pinEnabled) { _, newValue in
                                        HapticManager.toggle()
                                        if newValue {
                                            viewModel.showingPINSetup = true
                                        } else {
                                            viewModel.disablePIN()
                                        }
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)

                            // Auto-lock (if security enabled)
                            if viewModel.biometricEnabled || viewModel.pinEnabled {
                                Divider()
                                    .padding(.leading, Spacing.rowDividerInset)

                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "timer")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: IconSize.category)

                                    Text("Auto-Lock")
                                        .font(AppTypography.bodyLarge())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Picker("", selection: $viewModel.autoLockTimeout) {
                                        Text("1 min").tag(1)
                                        Text("5 min").tag(5)
                                        Text("15 min").tag(15)
                                        Text("30 min").tag(30)
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Privacy Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Privacy")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: IconSize.category)

                                Text("Show Balance to Contacts")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Toggle("", isOn: $viewModel.showBalanceToContacts)
                                    .labelsHidden()
                                    .onChange(of: viewModel.showBalanceToContacts) { _, _ in
                                        HapticManager.toggle()
                                        UserDefaults.standard.set(viewModel.showBalanceToContacts, forKey: "show_balance_to_contacts")
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)

                            Divider()
                                .padding(.leading, Spacing.rowDividerInset)

                            HStack(spacing: Spacing.md) {
                                Image(systemName: "clock")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: IconSize.category)

                                Text("Show Last Seen")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Toggle("", isOn: $viewModel.showLastSeen)
                                    .labelsHidden()
                                    .onChange(of: viewModel.showLastSeen) { _, _ in
                                        HapticManager.toggle()
                                        UserDefaults.standard.set(viewModel.showLastSeen, forKey: "show_last_seen")
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Data Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Data")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        HStack(spacing: Spacing.md) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.accent)
                                .frame(width: IconSize.category)

                            Text("Share Analytics")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Toggle("", isOn: $viewModel.allowAnalytics)
                                .labelsHidden()
                                .onChange(of: viewModel.allowAnalytics) { _, _ in
                                    HapticManager.toggle()
                                    UserDefaults.standard.set(viewModel.allowAnalytics, forKey: "allow_analytics")
                                }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Danger Zone
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Danger Zone")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.negative)
                            .padding(.horizontal, Spacing.sm)

                        Button {
                            HapticManager.warning()
                            viewModel.showingDeleteAccount = true
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.negative)
                                    .frame(width: IconSize.category)

                                Text("Clear All Data")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.negative)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.negative.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadSettings()
        }
        .alert("Biometric Error", isPresented: $viewModel.showingBiometricError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.biometricErrorMessage)
        }
        .alert("Clear All Data", isPresented: $viewModel.showingDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text("This will permanently delete all your data and sign you out.")
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
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(AppColors.accent)

                Text(step == .enter ? "Create PIN" : "Confirm PIN")
                    .font(AppTypography.displayMedium())
                    .foregroundColor(AppColors.textPrimary)

                Text(step == .enter ? "Enter a 6-digit PIN" : "Re-enter your PIN")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: Spacing.md) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index < currentPIN.count ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                            .frame(width: IconSize.sm, height: IconSize.sm)
                    }
                }
                .padding(.vertical, Spacing.lg)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.negative)
                }

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
            .navigationTitle("PIN Lock")
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
                    errorMessage = "PINs don't match"
                    confirmPin = ""
                    step = .enter
                    pin = ""
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySecurityView()
    }
}
