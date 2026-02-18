//
//  PhoneLoginView.swift
//  Swiss Coin
//
//  Two-step authentication flow:
//  Step 1: Phone number input → sends OTP via Supabase
//  Step 2: 6-digit OTP verification → signs in
//

import SwiftUI

struct PhoneLoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isAnimating = false
    @State private var step: LoginStep = .phone
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var resendTimer = 0
    @State private var timerTask: Task<Void, Never>?

    private enum LoginStep {
        case phone
        case otp
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppColors.accent.opacity(0.08),
                    AppColors.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                VStack(spacing: Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)

                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: IconSize.xxl + 32))
                            .foregroundStyle(AppColors.accent)
                            .scaleEffect(isAnimating ? 1.02 : 1.0)
                    }
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                    Text("Swiss Coin")
                        .font(AppTypography.displayHero())
                        .foregroundStyle(AppColors.textPrimary)

                    Text(step == .phone
                        ? "Enter your phone number to get started"
                        : "Enter the code sent to\n\(phoneNumber)")
                        .font(AppTypography.bodyDefault())
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, Spacing.xxxl)

                // Step content
                VStack(spacing: Spacing.lg) {
                    switch step {
                    case .phone:
                        phoneInputSection
                    case .otp:
                        otpInputSection
                    }
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(AppTypography.bodySmall())
                        .foregroundStyle(AppColors.negative)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.bottom, Spacing.md)
                }

                // Action button
                Button {
                    HapticManager.tap()
                    Task { await handleAction() }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .tint(AppColors.onAccent)
                    } else {
                        Text(step == .phone ? "Send Code" : "Verify")
                            .font(AppTypography.buttonDefault())
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isActionEnabled))
                .disabled(!isActionEnabled || authManager.isLoading)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.lg)

                // Footer / back button
                Group {
                    if step == .otp {
                        HStack(spacing: Spacing.sm) {
                            Button {
                                HapticManager.tap()
                                withAnimation(AppAnimation.standard) {
                                    step = .phone
                                    otpCode = ""
                                    authManager.errorMessage = nil
                                }
                            } label: {
                                Text("Change number")
                                    .font(AppTypography.bodySmall())
                                    .foregroundStyle(AppColors.textLink)
                            }

                            if resendTimer > 0 {
                                Text("Resend in \(resendTimer)s")
                                    .font(AppTypography.bodySmall())
                                    .foregroundStyle(AppColors.textTertiary)
                            } else {
                                Button {
                                    HapticManager.tap()
                                    Task {
                                        await authManager.sendPhoneOTP(phone: phoneNumber)
                                        startResendTimer()
                                    }
                                } label: {
                                    Text("Resend code")
                                        .font(AppTypography.bodySmall())
                                        .foregroundStyle(AppColors.textLink)
                                }
                            }
                        }
                    } else {
                        Text("We'll send you a verification code via SMS.")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.sectionGap)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .animation(AppAnimation.standard, value: step)
    }

    // MARK: - Phone Input

    private var phoneInputSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text("+1")
                    .font(AppTypography.bodyLarge())
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: ButtonHeight.input)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                TextField("Phone number", text: $phoneNumber)
                    .font(AppTypography.bodyLarge())
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: ButtonHeight.input)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
    }

    // MARK: - OTP Input

    private var otpInputSection: some View {
        VStack(spacing: Spacing.md) {
            TextField("6-digit code", text: $otpCode)
                .font(AppTypography.financialLarge())
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding(.horizontal, Spacing.md)
                .frame(height: ButtonHeight.input)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .onChange(of: otpCode) { _, newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        otpCode = String(newValue.prefix(6))
                    }
                }
        }
    }

    // MARK: - Actions

    private var isActionEnabled: Bool {
        switch step {
        case .phone:
            return phoneNumber.count >= 10
        case .otp:
            return otpCode.count == 6
        }
    }

    private func handleAction() async {
        switch step {
        case .phone:
            let formattedPhone = formatPhoneNumber(phoneNumber)
            await authManager.sendPhoneOTP(phone: formattedPhone)
            if authManager.errorMessage == nil {
                withAnimation(AppAnimation.standard) {
                    phoneNumber = formattedPhone
                    step = .otp
                }
                startResendTimer()
            }
        case .otp:
            await authManager.verifyPhoneOTP(phone: phoneNumber, token: otpCode)
        }
    }

    /// Format phone number to E.164 (prepend +1 if no country code)
    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter(\.isNumber)
        if digits.hasPrefix("1") && digits.count == 11 {
            return "+\(digits)"
        }
        return "+1\(digits)"
    }

    private func startResendTimer() {
        resendTimer = 60
        timerTask?.cancel()
        timerTask = Task {
            while resendTimer > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendTimer -= 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PhoneLoginView()
}
