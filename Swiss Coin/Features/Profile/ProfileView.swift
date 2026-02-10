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
    @State private var userPhoto: UIImage?

    // Settings
    @AppStorage("default_currency") private var defaultCurrency = "USD"
    @AppStorage("theme_mode") private var themeMode = "system"
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("reduce_motion") private var reduceMotion = false

    // Security
    @State private var darkModeOn = false
    @State private var biometricEnabled = false
    @State private var pinEnabled = false
    @State private var biometricType: LABiometryType = .none
    @State private var showingPINSetup = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""

    // Currency list (reuses CurrencyOption from CurrencySettingsView)
    private let currencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar", symbol: "$", flag: "\u{1F1FA}\u{1F1F8}"),
        CurrencyOption(code: "EUR", name: "Euro", symbol: "\u{20AC}", flag: "\u{1F1EA}\u{1F1FA}"),
        CurrencyOption(code: "GBP", name: "British Pound", symbol: "\u{00A3}", flag: "\u{1F1EC}\u{1F1E7}"),
        CurrencyOption(code: "CHF", name: "Swiss Franc", symbol: "CHF", flag: "\u{1F1E8}\u{1F1ED}"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar", symbol: "CA$", flag: "\u{1F1E8}\u{1F1E6}"),
        CurrencyOption(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "\u{1F1E6}\u{1F1FA}"),
        CurrencyOption(code: "JPY", name: "Japanese Yen", symbol: "\u{00A5}", flag: "\u{1F1EF}\u{1F1F5}"),
        CurrencyOption(code: "INR", name: "Indian Rupee", symbol: "\u{20B9}", flag: "\u{1F1EE}\u{1F1F3}"),
        CurrencyOption(code: "CNY", name: "Chinese Yuan", symbol: "\u{00A5}", flag: "\u{1F1E8}\u{1F1F3}"),
        CurrencyOption(code: "KRW", name: "South Korean Won", symbol: "\u{20A9}", flag: "\u{1F1F0}\u{1F1F7}"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "\u{1F1F8}\u{1F1EC}"),
        CurrencyOption(code: "AED", name: "UAE Dirham", symbol: "AED", flag: "\u{1F1E6}\u{1F1EA}"),
        CurrencyOption(code: "BRL", name: "Brazilian Real", symbol: "R$", flag: "\u{1F1E7}\u{1F1F7}"),
        CurrencyOption(code: "MXN", name: "Mexican Peso", symbol: "MX$", flag: "\u{1F1F2}\u{1F1FD}"),
        CurrencyOption(code: "SEK", name: "Swedish Krona", symbol: "kr", flag: "\u{1F1F8}\u{1F1EA}"),
        CurrencyOption(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "\u{1F1F3}\u{1F1FF}"),
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
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        profileSection
                        generalSection
                        notificationsSection
                        securitySection
                        aboutSection
                        logOutSection
                    }
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.section)
                }
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
        NavigationLink(destination: PersonalDetailsView()) {
            HStack(spacing: Spacing.md) {
                // Avatar - show photo or initials
                Group {
                    if let photo = userPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: userColor).opacity(0.3), lineWidth: 2)
                            )
                    } else {
                        Circle()
                            .fill(Color(hex: userColor).opacity(0.15))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(userInitials)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(Color(hex: userColor))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: userColor).opacity(0.2), lineWidth: 2)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(userName)
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text("Personal Details")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
        .background(AppColors.cardBackground)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GENERAL")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                HStack {
                    Text("Currency")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Picker("", selection: $defaultCurrency) {
                        ForEach(currencies) { currency in
                            Text("\(currency.flag) \(currency.code) - \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                    .labelsHidden()
                    .tint(AppColors.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                Divider()
                    .padding(.leading, Spacing.lg)

                HStack {
                    Text("Dark Mode")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: $darkModeOn)
                        .labelsHidden()
                        .onChange(of: darkModeOn) { _, newValue in
                            HapticManager.toggle()
                            let newMode = newValue ? "dark" : "light"
                            ThemeTransitionManager.shared.transition(to: newMode, reduceMotion: reduceMotion)
                            themeMode = newMode
                        }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(AppColors.cardBackground)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("NOTIFICATIONS")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            HStack {
                Text("Notifications")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .onChange(of: notificationsEnabled) { _, _ in
                        HapticManager.toggle()
                    }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackground)
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SECURITY")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                if biometricType != .none {
                    HStack {
                        Text(biometricLabel)
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Toggle("", isOn: $biometricEnabled)
                            .labelsHidden()
                            .onChange(of: biometricEnabled) { _, newValue in
                                if newValue {
                                    enableBiometric()
                                } else {
                                    disableBiometric()
                                }
                            }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)

                    Divider()
                        .padding(.leading, Spacing.lg)
                }

                HStack {
                    Text("PIN Lock")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: $pinEnabled)
                        .labelsHidden()
                        .onChange(of: pinEnabled) { _, newValue in
                            HapticManager.toggle()
                            if newValue {
                                showingPINSetup = true
                            } else {
                                disablePIN()
                            }
                        }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(AppColors.cardBackground)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ABOUT")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                Divider()
                    .padding(.leading, Spacing.lg)

                Button {
                    HapticManager.tap()
                    openURL("https://swisscoin.app/help")
                } label: {
                    HStack {
                        Text("Help Center")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, Spacing.lg)

                Button {
                    HapticManager.tap()
                    shareApp()
                } label: {
                    HStack {
                        Text("Share Swiss Coin")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(AppColors.cardBackground)
        }
    }

    private var logOutSection: some View {
        Button {
            HapticManager.warning()
            showingLogoutAlert = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: IconSize.sm))
                Text("Log Out")
                    .font(AppTypography.subheadlineMedium())
            }
            .foregroundColor(.white)
            .frame(height: ButtonHeight.md)
            .frame(maxWidth: .infinity)
            .background(AppColors.negative)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Functions

    private func loadCurrentUser() {
        currentUser = CurrentUser.getOrCreate(in: viewContext)
        if let photoData = currentUser?.photoData, let image = UIImage(data: photoData) {
            userPhoto = image
        }
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
