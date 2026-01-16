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
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)

                    Text("Swiss Coin")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Split expenses with friends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 60)

                // Phone input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        // Country code picker
                        Menu {
                            ForEach(countryCodes, id: \.self) { code in
                                Button(code) {
                                    countryCode = code
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(countryCode)
                                    .font(.body)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Phone number field
                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Sign in button
                Button(action: signIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidPhone ? Color.green : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValidPhone || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Terms text
                Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
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
