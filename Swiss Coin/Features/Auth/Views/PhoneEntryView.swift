//
//  PhoneEntryView.swift
//  Swiss Coin
//
//  Post-Apple-Sign-In phone verification using Firebase Phone Auth.
//  Users verify their phone number via SMS OTP for contact discovery.
//

import CoreData
import CryptoKit
import FirebaseAuth
import SwiftUI

// MARK: - Phone Entry Step

private enum PhoneEntryStep {
    case enterPhone
    case enterOTP
}

// MARK: - PhoneEntryView

struct PhoneEntryView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.managedObjectContext) private var viewContext

    // Phone input state
    @State private var selectedCountry = CountryCode.unitedStates
    @State private var phoneDigits = ""
    @State private var showCountryPicker = false

    // OTP input state
    @State private var otpCode = ""
    @FocusState private var otpFocused: Bool

    // Firebase verification
    @State private var verificationID: String?

    // Flow state
    @State private var step: PhoneEntryStep = .enterPhone
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0

    // Resend cooldown
    @State private var resendCooldown = 0
    @State private var resendTimer: Timer?

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

    private var isOTPValid: Bool {
        otpCode.filter(\.isNumber).count == 6
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

    private var maskedPhone: String {
        let phone = e164Phone
        guard phone.count > 4 else { return phone }
        let lastFour = phone.suffix(4)
        let masked = String(repeating: "•", count: phone.count - 4)
        return masked + lastFour
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

                    // Input section based on step
                    Group {
                        switch step {
                        case .enterPhone:
                            phoneInputSection
                        case .enterOTP:
                            otpInputSection
                        }
                    }
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
        .animation(AppAnimation.standard, value: step)
        .animation(AppAnimation.standard, value: showError)
        .animation(AppAnimation.standard, value: isLoading)
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePicker(selectedCountry: $selectedCountry)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFocused = true
            }
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: step == .enterPhone ? "phone.badge.plus" : "checkmark.message")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                if step == .enterPhone {
                    Text("Welcome, \(displayName)!")
                        .font(AppTypography.displayMedium())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Verify your phone number so friends can find you on Swiss Coin.")
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Enter verification code")
                        .font(AppTypography.displayMedium())
                        .foregroundColor(AppColors.textPrimary)

                    Text("We sent a 6-digit code to\n\(maskedPhone)")
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1)
                    .padding(.vertical, Spacing.sm)

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

            Text("We'll send a verification code via SMS.")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: - OTP Input Section

    private var otpInputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Verification Code")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textSecondary)

            TextField("000000", text: $otpCode)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.vertical, Spacing.lg)
                .background(AppColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(showError ? AppColors.negative : AppColors.divider, lineWidth: 1)
                )
                .focused($otpFocused)
                .onChange(of: otpCode) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits.count > 6 {
                        otpCode = String(digits.prefix(6))
                    } else {
                        otpCode = digits
                    }
                    if showError { showError = false }

                    // Auto-submit when 6 digits entered
                    if otpCode.count == 6 {
                        Task { await verifyOTP() }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        otpFocused = true
                    }
                }

            // Resend button
            HStack {
                Spacer()
                if resendCooldown > 0 {
                    Text("Resend code in \(resendCooldown)s")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    Button {
                        HapticManager.lightTap()
                        Task { await sendOTP() }
                    } label: {
                        Text("Resend code")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.accent)
                    }
                    .disabled(isLoading)
                }
                Spacer()
            }
            .padding(.top, Spacing.sm)

            // Change number button
            HStack {
                Spacer()
                Button {
                    HapticManager.lightTap()
                    withAnimation {
                        step = .enterPhone
                        otpCode = ""
                        verificationID = nil
                        showError = false
                        resendTimer?.invalidate()
                        resendCooldown = 0
                    }
                } label: {
                    Text("Change phone number")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
                .disabled(isLoading)
                Spacer()
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                Task {
                    switch step {
                    case .enterPhone:
                        await sendOTP()
                    case .enterOTP:
                        await verifyOTP()
                    }
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(step == .enterPhone ? "Send Code" : "Verify")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || (step == .enterPhone ? !isPhoneValid : !isOTPValid))

            // Skip button (only on phone entry step)
            if step == .enterPhone {
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
    }

    // MARK: - Firebase Phone Auth

    private func sendOTP() async {
        guard isPhoneValid else {
            showErrorWithShake("Please enter a valid phone number")
            return
        }

        isLoading = true
        showError = false

        do {
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
                e164Phone,
                uiDelegate: nil
            )
            
            self.verificationID = verificationID
            HapticManager.success()
            startResendCooldown()
            
            withAnimation {
                step = .enterOTP
            }
        } catch {
            print("Firebase sendOTP error: \(error)")
            let errorMessage = mapFirebaseError(error)
            showErrorWithShake(errorMessage)
        }

        isLoading = false
    }

    private func verifyOTP() async {
        guard isOTPValid else {
            showErrorWithShake("Please enter the 6-digit code")
            return
        }

        guard let verificationID = verificationID else {
            showErrorWithShake("Verification expired. Please request a new code.")
            return
        }

        isLoading = true
        showError = false

        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: otpCode
            )

            // Sign in with Firebase to verify the code
            let result = try await Auth.auth().signIn(with: credential)
            
            print("Firebase phone verified for: \(result.user.phoneNumber ?? "unknown")")
            
            // Save phone locally and update Supabase profile
            await savePhoneLocally(phone: e164Phone)
            
            // Sign out of Firebase (we only used it for verification)
            try? Auth.auth().signOut()
            
            HapticManager.success()
            authManager.completePhoneEntry()
            
        } catch {
            isLoading = false
            print("Firebase verifyOTP error: \(error)")
            let errorMessage = mapFirebaseError(error)
            showErrorWithShake(errorMessage)
        }
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.invalidPhoneNumber.rawValue:
            return "Invalid phone number. Please check and try again."
        case AuthErrorCode.missingPhoneNumber.rawValue:
            return "Please enter a phone number."
        case AuthErrorCode.quotaExceeded.rawValue:
            return "Too many requests. Please try again later."
        case AuthErrorCode.invalidVerificationCode.rawValue:
            return "Incorrect code. Please try again."
        case AuthErrorCode.sessionExpired.rawValue:
            return "Code expired. Please request a new one."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please wait and try again."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        default:
            return error.localizedDescription
        }
    }

    private func skipPhoneEntry() {
        UserDefaults.standard.set(true, forKey: "user_phone_skipped")
        authManager.completePhoneEntry()
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
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

        // Update Supabase profile with phone hash
        await updateSupabaseProfile(phone: phone)

        // Trigger contact discovery
        Task {
            await ContactDiscoveryService.shared.discoverContacts(context: viewContext)
            let _ = await SharedDataService.shared.claimPendingShares()
        }
    }

    private func updateSupabaseProfile(phone: String) async {
        guard let userId = AuthManager.shared.currentUserId else { return }
        
        let phoneHash = hashPhoneNumber(phone)
        
        do {
            try await SupabaseConfig.client.from("profiles")
                .update([
                    "phone_number": phone,
                    "phone_hash": phoneHash,
                    "phone_verified": true
                ])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            print("Failed to update Supabase profile: \(error)")
        }
    }

    private func showErrorWithShake(_ message: String) {
        errorMessage = message
        showError = true
        HapticManager.error()

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

    private func formatForDisplay(digits: String, countryId: String) -> String {
        let chars = Array(digits)
        let groups: [Int]
        switch countryId {
        case "CH", "AT": groups = [2, 3, 2, 2]
        case "US", "CA": groups = [3, 3, 4]
        case "GB": groups = [4, 6]
        case "DE": groups = [3, 4, 4]
        case "IN": groups = [5, 5]
        case "FR", "IT": groups = [1, 2, 2, 2, 2]
        default: groups = [3, 3, 3, 3]
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
