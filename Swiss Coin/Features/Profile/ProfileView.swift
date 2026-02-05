//
//  ProfileView.swift
//  Swiss Coin
//
//  Single-page settings with inline toggles and pickers. Apple Settings style.
//

import CoreData
import CryptoKit
import LocalAuthentication
import SwiftUI

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var currentUser: Person?
    @State private var showingLogoutAlert = false

    // Settings
    @AppStorage("default_currency") private var defaultCurrency = "USD"
    @AppStorage("theme_mode") private var themeMode = "system"
    @AppStorage("notifications_enabled") private var notificationsEnabled = true

    // Security
    @State private var darkModeOn = false
    @State private var biometricEnabled = false
    @State private var pinEnabled = false
    @State private var biometricType: LABiometryType = .none
    @State private var showingPINSetup = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""

    // Currency list
    private let currencies: [(code: String, name: String, flag: String)] = [
        ("USD", "US Dollar", "\u{1F1FA}\u{1F1F8}"),
        ("EUR", "Euro", "\u{1F1EA}\u{1F1FA}"),
        ("GBP", "British Pound", "\u{1F1EC}\u{1F1E7}"),
        ("CHF", "Swiss Franc", "\u{1F1E8}\u{1F1ED}"),
        ("CAD", "Canadian Dollar", "\u{1F1E8}\u{1F1E6}"),
        ("AUD", "Australian Dollar", "\u{1F1E6}\u{1F1FA}"),
        ("JPY", "Japanese Yen", "\u{1F1EF}\u{1F1F5}"),
        ("INR", "Indian Rupee", "\u{1F1EE}\u{1F1F3}"),
        ("CNY", "Chinese Yuan", "\u{1F1E8}\u{1F1F3}"),
        ("KRW", "South Korean Won", "\u{1F1F0}\u{1F1F7}"),
        ("SGD", "Singapore Dollar", "\u{1F1F8}\u{1F1EC}"),
        ("AED", "UAE Dirham", "\u{1F1E6}\u{1F1EA}"),
        ("BRL", "Brazilian Real", "\u{1F1E7}\u{1F1F7}"),
        ("MXN", "Mexican Peso", "\u{1F1F2}\u{1F1FD}"),
        ("SEK", "Swedish Krona", "\u{1F1F8}\u{1F1EA}"),
        ("NZD", "New Zealand Dollar", "\u{1F1F3}\u{1F1FF}"),
    ]

    // MARK: - Computed

    private var userName: String {
        currentUser?.name ?? "You"
    }

    private var userInitials: String {
        currentUser?.initials ?? "ME"
    }

    private var userColor: String {
        currentUser?.colorHex ?? AppColors.defaultAvatarColorHex
    }

    private var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometric Lock"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                generalSection
                notificationsSection
                securitySection
                aboutSection
                logOutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.tap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                HapticManager.prepare()
                loadCurrentUser()
                loadSecuritySettings()
                darkModeOn = themeMode == "dark"
            }
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) { logOut() }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Biometric Error", isPresented: $showingBiometricError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(biometricErrorMessage)
            }
            .sheet(isPresented: $showingPINSetup) {
                PINSetupView(
                    onComplete: { pin in savePIN(pin) },
                    onCancel: { pinEnabled = false }
                )
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            NavigationLink(destination: PersonalDetailsView()) {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: userColor).opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(userInitials)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(hex: userColor))
                        )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(userName)
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Text("Edit Profile")
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    private var generalSection: some View {
        Section {
            Picker("Currency", selection: $defaultCurrency) {
                ForEach(currencies, id: \.code) { currency in
                    Text("\(currency.flag) \(currency.code) - \(currency.name)")
                        .tag(currency.code)
                }
            }

            Toggle("Dark Mode", isOn: $darkModeOn)
                .onChange(of: darkModeOn) { _, newValue in
                    HapticManager.toggle()
                    themeMode = newValue ? "dark" : "system"
                }
        } header: {
            Text("General")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, _ in
                    HapticManager.toggle()
                }
        } header: {
            Text("Notifications")
        }
    }

    private var securitySection: some View {
        Section {
            if biometricType != .none {
                Toggle(biometricLabel, isOn: $biometricEnabled)
                    .onChange(of: biometricEnabled) { _, newValue in
                        if newValue {
                            enableBiometric()
                        } else {
                            disableBiometric()
                        }
                    }
            }

            Toggle("PIN Lock", isOn: $pinEnabled)
                .onChange(of: pinEnabled) { _, newValue in
                    HapticManager.toggle()
                    if newValue {
                        showingPINSetup = true
                    } else {
                        disablePIN()
                    }
                }
        } header: {
            Text("Security")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(AppColors.textSecondary)
            }

            Button {
                HapticManager.tap()
                openURL("https://swisscoin.app/help")
            } label: {
                HStack {
                    Text("Help Center")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Button {
                HapticManager.tap()
                shareApp()
            } label: {
                HStack {
                    Text("Share Swiss Coin")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        } header: {
            Text("About")
        }
    }

    private var logOutSection: some View {
        Section {
            Button(role: .destructive) {
                HapticManager.warning()
                showingLogoutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Log Out")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Functions

    private func loadCurrentUser() {
        currentUser = CurrentUser.getOrCreate(in: viewContext)
    }

    private func loadSecuritySettings() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
        pinEnabled = UserDefaults.standard.bool(forKey: "pin_enabled")
    }

    private func enableBiometric() {
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

    private func disableBiometric() {
        HapticManager.toggle()
        UserDefaults.standard.set(false, forKey: "biometric_enabled")
    }

    private func savePIN(_ pin: String) {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        let pinHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        KeychainHelper.save(key: "user_pin_hash", value: pinHash)
        pinEnabled = true
        UserDefaults.standard.set(true, forKey: "pin_enabled")
        HapticManager.success()
    }

    private func disablePIN() {
        KeychainHelper.delete(key: "user_pin_hash")
        UserDefaults.standard.set(false, forKey: "pin_enabled")
    }

    private func logOut() {
        HapticManager.warning()
        AuthManager.shared.signOut()
        dismiss()
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func shareApp() {
        let shareText = "Check out Swiss Coin - the easiest way to split expenses with friends!"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    ProfileView()
}
