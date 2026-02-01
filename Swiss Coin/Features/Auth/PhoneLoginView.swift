//
//  PhoneLoginView.swift
//  Swiss Coin
//
//  Simple phone number login view for authentication.
//  Users enter their phone number to sign in automatically.
//

import SwiftUI

struct PhoneLoginView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @State private var phoneNumber: String = ""
    @State private var countryCode: String = "+1"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    private let countryCodes = ["+1", "+44", "+91", "+61", "+81", "+86", "+49", "+33", "+39", "+34"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: IconSize.xxl + 32))
                        .foregroundStyle(AppColors.accent)

                    Text("Swiss Coin")
                        .font(AppTypography.largeTitle())
                    
                    Text("Split expenses with friends")
                        .font(AppTypography.subheadline())
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.bottom, Spacing.section + Spacing.xxl + Spacing.sm)

                // Phone input section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Phone Number")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: Spacing.md) {
                        // Country code picker
                        Menu {
                            ForEach(countryCodes, id: \.self) { code in
                                Button(code) {
                                    countryCode = code
                                }
                            }
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Text(countryCode)
                                    .font(AppTypography.body())
                                Image(systemName: "chevron.down")
                                    .font(AppTypography.caption())
                            }
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + Spacing.xs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        }

                        // Phone number field
                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(AppTypography.body())
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm + Spacing.xs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                            .onChange(of: phoneNumber) { _, newValue in
                                // Remove any non-digit characters except for common formatting
                                let filtered = newValue.filter { $0.isNumber || $0 == "-" || $0 == " " || $0 == "(" || $0 == ")" }
                                if filtered != newValue {
                                    phoneNumber = filtered
                                }
                            }
                    }
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Sign in button
                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .font(AppTypography.bodyBold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(isValidPhone ? AppColors.accent : AppColors.disabled)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .disabled(!isValidPhone || isLoading)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.lg)

                // Terms text
                Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.section + Spacing.sm)
                    .padding(.bottom, Spacing.section)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private var isValidPhone: Bool {
        // Basic validation: at least 7 digits
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.count >= 7
    }

    private var fullPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        return countryCode + digits
    }

    private func signIn() {
        guard isValidPhone else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await supabase.signInWithPhone(phoneNumber: fullPhoneNumber)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    PhoneLoginView()
}
