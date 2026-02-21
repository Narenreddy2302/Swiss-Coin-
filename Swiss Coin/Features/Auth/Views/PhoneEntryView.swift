//
//  PhoneEntryView.swift
//  Swiss Coin
//
//  Post-Apple-Sign-In phone verification gate. Users verify their phone number
//  via SMS OTP so friends can find and connect with them via contact discovery.
//  Phone verification is mandatory for contact discovery.
//

import CoreData
import CryptoKit
import Functions
import Supabase
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
            // Auto-focus phone input after a brief delay
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
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: step == .enterPhone ? "phone.badge.plus" : "checkmark.message")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.accent)
            }
            .accessibilityHidden(true)

            // Welcome text
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
            .background(AppColors.backgroundSecondary)
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

            // OTP input field
            TextField("000000", text: $otpCode)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.vertical, Spacing.lg)
                .background(AppColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(showError ? AppColors.negative : AppColors.divider, lineWidth: 1)
                )
                .focused($otpFocused)
                .onChange(of: otpCode) { _, newValue in
                    // Keep only digits, max 6
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
                        Task { await resendOTP() }
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
            // Primary action button
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
        }
    }

    // MARK: - Actions

    private func sendOTP() async {
        guard isPhoneValid else {
            showErrorWithShake("Please enter a valid phone number")
            return
        }

        isLoading = true
        showError = false

        do {
            let result = try await callSendOTP(phone: e164Phone)

            if result.success {
                HapticManager.success()
                startResendCooldown()
                withAnimation {
                    step = .enterOTP
                }
            } else {
                showErrorWithShake(result.error ?? "Failed to send code. Please try again.")
            }
        } catch let functionsError as FunctionsError {
            if case .httpError(let code, let data) = functionsError {
                print("FunctionsError.httpError code: \(code), body: \(String(data: data, encoding: .utf8) ?? "nil")")
                if let body = try? JSONDecoder().decode(OTPResponse.self, from: data) {
                    showErrorWithShake(body.error ?? "Failed to send code. Please try again.")
                } else {
                    // Decode failed — try to show raw response
                    let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
                    showErrorWithShake(raw)
                }
            } else {
                print("FunctionsError (not httpError): \(functionsError)")
                showErrorWithShake("Relay error. Please try again.")
            }
        } catch {
            print("Unexpected error calling send-phone-otp: \(error)")
            showErrorWithShake("Connection error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func resendOTP() async {
        isLoading = true
        showError = false

        do {
            let result = try await callSendOTP(phone: e164Phone)

            if result.success {
                HapticManager.success()
                startResendCooldown()
            } else {
                showErrorWithShake(result.error ?? "Failed to resend code.")
            }
        } catch let functionsError as FunctionsError {
            if case .httpError(_, let data) = functionsError,
               let body = try? JSONDecoder().decode(OTPResponse.self, from: data) {
                showErrorWithShake(body.error ?? "Failed to resend code.")
            } else {
                showErrorWithShake("Connection error. Please try again.")
            }
        } catch {
            showErrorWithShake("Connection error. Please try again.")
        }

        isLoading = false
    }

    private func verifyOTP() async {
        guard isOTPValid else {
            showErrorWithShake("Please enter the 6-digit code")
            return
        }

        isLoading = true
        showError = false

        do {
            let result = try await callVerifyOTP(phone: e164Phone, code: otpCode)

            if result.success {
                // Verification successful
                await savePhoneLocally(phone: e164Phone)
                HapticManager.success()
                authManager.completePhoneEntry()
            } else {
                isLoading = false
                showErrorWithShake(result.error ?? "Verification failed. Please try again.")
            }
        } catch let functionsError as FunctionsError {
            isLoading = false
            if case .httpError(_, let data) = functionsError,
               let body = try? JSONDecoder().decode(OTPResponse.self, from: data) {
                showErrorWithShake(body.error ?? "Verification failed. Please try again.")
            } else {
                showErrorWithShake("Connection error. Please try again.")
            }
        } catch {
            isLoading = false
            showErrorWithShake("Connection error. Please check your internet and try again.")
        }
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

    // MARK: - API Calls

    private struct OTPResponse: Decodable {
        let success: Bool
        let status: String?
        let action: String?
        let error: String?
    }

    private func callSendOTP(phone: String) async throws -> OTPResponse {
        // Ensure we have an active session
        guard let session = try? await SupabaseConfig.client.auth.session else {
            return OTPResponse(success: false, status: nil, action: nil, error: "Not authenticated")
        }
        
        print("Calling send-phone-otp with session user: \(session.user.id)")
        
        return try await SupabaseConfig.client.functions.invoke(
            "send-phone-otp",
            options: .init(body: ["phone": phone])
        )
    }

    private func callVerifyOTP(phone: String, code: String) async throws -> OTPResponse {
        // Ensure we have an active session
        guard let _ = try? await SupabaseConfig.client.auth.session else {
            return OTPResponse(success: false, status: nil, action: nil, error: "Not authenticated")
        }
        
        return try await SupabaseConfig.client.functions.invoke(
            "verify-phone-otp",
            options: .init(body: ["phone": phone, "code": code])
        )
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
}

// MARK: - Preview

#Preview {
    PhoneEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
