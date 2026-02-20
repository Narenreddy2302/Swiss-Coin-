//
//  PhoneEntryView.swift
//  Swiss Coin
//
//  Post-Apple-Sign-In phone entry gate. Users add their phone number
//  so friends can find and connect with them via contact discovery.
//  Phone is optional — users can skip and add it later in Profile.
//

import CoreData
import CryptoKit
import SwiftUI

struct PhoneEntryView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCountry = CountryCode.unitedStates
    @State private var phoneDigits = ""
    @State private var showCountryPicker = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0

    // Merge conflict state
    @State private var showMergeConfirmation = false
    @State private var conflictDisplayName: String?
    @State private var pendingPhoneHash = ""

    @FocusState private var isPhoneFocused: Bool

    // MARK: - Computed Properties

    private var e164Phone: String {
        let digits = phoneDigits.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return selectedCountry.dialCode + digits
    }

    private var isPhoneValid: Bool {
        let digits = phoneDigits.filter(\.isNumber)
        return digits.count >= 6 && digits.count <= 15
    }

    private var formattedPhoneInput: String {
        let digits = phoneDigits.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return formatForDisplay(digits: digits, countryId: selectedCountry.id)
    }

    private var displayName: String {
        UserDefaults.standard.string(forKey: "apple_given_name")
            ?? UserDefaults.standard.string(forKey: "apple_full_name")
            ?? "there"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: Spacing.xxxl * 2)

                    // Hero section
                    heroSection

                    Spacer()
                        .frame(height: Spacing.xxxl)

                    // Phone input
                    phoneInputSection
                        .offset(x: shakeOffset)

                    // Error message
                    if showError {
                        Text(errorMessage)
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.negative)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.top, Spacing.md)
                            .transition(.opacity)
                    }

                    Spacer()
                        .frame(height: Spacing.xxl)

                    // Actions
                    actionSection

                    Spacer()
                        .frame(minHeight: Spacing.xxxl)
                }
                .padding(.horizontal, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(AppAnimation.standard, value: showError)
        .animation(AppAnimation.standard, value: isLoading)
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePicker(selectedCountry: $selectedCountry)
        }
        .alert("Account Found", isPresented: $showMergeConfirmation) {
            Button("Link Account") {
                HapticManager.tap()
                Task { await confirmMerge() }
            }
            Button("Cancel", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text("A Swiss Coin account with this phone number already exists\(conflictDisplayName.map { " (\($0))" } ?? ""). Would you like to link it to your Apple ID? All your existing data will be preserved.")
        }
        .onAppear {
            // Auto-focus phone input after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFocused = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            // Welcome text
            VStack(spacing: Spacing.sm) {
                Text("Welcome, \(displayName)!")
                    .font(AppTypography.displayMedium())
                    .foregroundColor(AppColors.textPrimary)

                Text("Add your phone number so friends can find and connect with you on Swiss Coin.")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Phone Input Section

    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Phone Number")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 0) {
                // Country code button
                Button {
                    HapticManager.lightTap()
                    isPhoneFocused = false
                    showCountryPicker = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(selectedCountry.flag)
                            .font(.system(size: IconSize.lg))

                        Text(selectedCountry.dialCode)
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: IconSize.xs, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                }
                .accessibilityLabel("\(selectedCountry.name), \(selectedCountry.dialCode)")
                .accessibilityHint("Double tap to change country code")

                // Divider
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1)
                    .padding(.vertical, Spacing.sm)

                // Phone number input
                TextField("Enter phone number", text: Binding(
                    get: { formattedPhoneInput },
                    set: { newValue in
                        phoneDigits = newValue.filter(\.isNumber)
                        if showError { showError = false }
                    }
                ))
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .focused($isPhoneFocused)
                .accessibilityLabel("Phone number")
                .accessibilityHint("Enter your phone number without the country code")
                .onChange(of: phoneDigits) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits.count > 15 {
                        phoneDigits = String(digits.prefix(15))
                    }
                }
            }
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(showError ? AppColors.negative : AppColors.divider, lineWidth: 1)
            )

            Text("Your phone number is used for contact discovery only. It's never shared publicly.")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: Spacing.md) {
            // Continue button
            Button {
                HapticManager.tap()
                Task { await submitPhone() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || phoneDigits.isEmpty || !isPhoneValid)

            // Skip button
            Button {
                HapticManager.lightTap()
                skipPhoneEntry()
            } label: {
                Text("Skip for now")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
            .disabled(isLoading)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Actions

    private func submitPhone() async {
        guard isPhoneValid else {
            showErrorWithShake("Please enter a valid phone number")
            return
        }

        isLoading = true
        showError = false

        let phone = e164Phone
        let phoneHash = hashPhoneNumber(phone)

        do {
            let result = try await authManager.linkPhoneToAccount(
                phone: phone,
                phoneHash: phoneHash,
                confirmMerge: false
            )

            switch result.action {
            case "phone_set":
                // Success — save locally and proceed
                await savePhoneLocally(phone: phone)
                HapticManager.success()
                authManager.completePhoneEntry()

            case "conflict":
                // Existing account found — show merge confirmation
                isLoading = false
                pendingPhoneHash = phoneHash
                conflictDisplayName = result.existingDisplayName
                showMergeConfirmation = true

            case "error":
                isLoading = false
                showErrorWithShake(result.error ?? "Failed to save phone number. Please try again.")

            default:
                isLoading = false
                showErrorWithShake("Unexpected response. Please try again.")
            }
        } catch {
            isLoading = false
            showErrorWithShake("Network error. Please check your connection and try again.")
        }
    }

    private func confirmMerge() async {
        isLoading = true

        do {
            let result = try await authManager.linkPhoneToAccount(
                phone: e164Phone,
                phoneHash: pendingPhoneHash,
                confirmMerge: true
            )

            if result.action == "accounts_merged" {
                await savePhoneLocally(phone: e164Phone)
                HapticManager.success()

                // Trigger sync to pull merged data
                SyncManager.shared.syncAll(context: viewContext)

                authManager.completePhoneEntry()
            } else {
                isLoading = false
                showErrorWithShake(result.error ?? "Account linking failed. Please try again.")
            }
        } catch {
            isLoading = false
            showErrorWithShake("Network error. Please try again.")
        }
    }

    private func skipPhoneEntry() {
        // Mark as skipped so we don't show the gate again this session
        // User can add phone later in Profile Settings
        UserDefaults.standard.set(true, forKey: "user_phone_skipped")
        authManager.completePhoneEntry()
    }

    private func savePhoneLocally(phone: String) async {
        // Save to UserDefaults
        UserDefaults.standard.set(phone, forKey: "user_phone_e164")
        UserDefaults.standard.set(true, forKey: "user_phone_collected")
        UserDefaults.standard.removeObject(forKey: "user_phone_skipped")

        // Save to CoreData
        await viewContext.perform {
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            currentUser.phoneNumber = phone
            try? viewContext.save()
        }

        // Trigger contact discovery
        Task {
            await ContactDiscoveryService.shared.discoverContacts(context: viewContext)
            let _ = await SharedDataService.shared.claimPendingShares()
        }
    }

    private func showErrorWithShake(_ message: String) {
        errorMessage = message
        showError = true
        HapticManager.error()

        // Shake animation
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                shakeOffset = 0
            }
        }
    }

    // MARK: - Helpers

    /// Country-aware phone number display grouping.
    private func formatForDisplay(digits: String, countryId: String) -> String {
        let chars = Array(digits)
        let groups: [Int]
        switch countryId {
        case "CH", "AT": groups = [2, 3, 2, 2]      // 79 123 45 67
        case "US", "CA": groups = [3, 3, 4]          // 555 123 4567
        case "GB":       groups = [4, 6]             // 7911 123456
        case "DE":       groups = [3, 4, 4]          // 151 1234 5678
        case "IN":       groups = [5, 5]             // 98765 43210
        case "FR", "IT": groups = [1, 2, 2, 2, 2]   // 6 12 34 56 78
        default:         groups = [3, 3, 3, 3]       // groups of 3
        }

        var result = ""
        var index = 0
        for (i, groupSize) in groups.enumerated() {
            guard index < chars.count else { break }
            if i > 0 { result += " " }
            let end = min(index + groupSize, chars.count)
            result += String(chars[index..<end])
            index = end
        }
        if index < chars.count {
            result += " " + String(chars[index...])
        }
        return result
    }

    /// SHA-256 hash of E.164 phone number for privacy-preserving discovery.
    private func hashPhoneNumber(_ phone: String) -> String {
        let data = Data(phone.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Preview

#Preview {
    PhoneEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
