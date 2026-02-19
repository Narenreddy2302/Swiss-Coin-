//
//  PhoneEntryView.swift
//  Swiss Coin
//
//  Phone number collection screen shown after Apple Sign-In.
//  Collects the user's phone number for contact discovery and profile setup.
//

import Combine
import CoreData
import CryptoKit
import Supabase
import SwiftUI

// MARK: - Phone Entry ViewModel

@MainActor
final class PhoneEntryViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var selectedCountry = CountryCode.switzerland
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    var isPhoneValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 6 && digits.count <= 15 else { return false }

        // E.164 total length check (country code + number: 7-15 digits)
        let e164 = selectedCountry.dialCode + digits
        let e164Digits = e164.filter(\.isNumber)
        return e164Digits.count >= 7 && e164Digits.count <= 15
    }

    var e164Phone: String {
        let digits = phoneNumber.filter(\.isNumber)
        return selectedCountry.dialCode + digits
    }

    /// Formatted display number grouped by country convention.
    var formattedDisplayNumber: String {
        let digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return Self.formatForDisplay(digits: digits, countryId: selectedCountry.id)
    }

    private static func formatForDisplay(digits: String, countryId: String) -> String {
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
        // Append any remaining digits beyond the grouping pattern
        if index < chars.count {
            result += " " + String(chars[index...])
        }
        return result
    }

    func submitPhone(context: NSManagedObjectContext) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let e164 = e164Phone

            // 1. Update Supabase profile
            guard let userId = AuthManager.shared.currentUserId else {
                errorMessage = "Session expired. Please sign in again."
                return
            }
            let givenName = UserDefaults.standard.string(forKey: "apple_given_name")
            let fullName = UserDefaults.standard.string(forKey: "apple_full_name")
            let email = KeychainHelper.read(key: "apple_email")

            // Hash the phone for contact discovery
            let phoneHash = Self.hashPhoneNumber(e164)

            try await SupabaseConfig.client.from("profiles")
                .update([
                    "phone": e164,
                    "phone_hash": phoneHash,
                    "display_name": givenName ?? "User",
                    "full_name": fullName,
                    "email": email,
                ] as [String: String?])
                .eq("id", value: userId.uuidString)
                .execute()

            // 2. Update local CoreData Person
            await context.perform {
                let person = CurrentUser.getOrCreate(in: context)
                person.phoneNumber = e164
                if let name = givenName ?? fullName {
                    person.name = name
                }
                try? context.save()
            }

            // 3. Store in UserDefaults
            UserDefaults.standard.set(e164, forKey: "user_phone_e164")
            UserDefaults.standard.set(true, forKey: "user_phone_collected")

            // 4. Transition auth state
            AuthManager.shared.completePhoneEntry()
            HapticManager.success()
        } catch {
            errorMessage = "Failed to save phone number. Please try again."
            HapticManager.error()
        }
    }

    // MARK: - Phone Hash

    /// SHA-256 hash of a phone number for privacy-preserving contact discovery.
    private static func hashPhoneNumber(_ phone: String) -> String {
        let data = Data(phone.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Phone Entry View

struct PhoneEntryView: View {
    @StateObject private var viewModel = PhoneEntryViewModel()
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showCountryPicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 72

    private var greeting: String {
        let name = UserDefaults.standard.string(forKey: "apple_given_name") ?? "there"
        return "Hi \(name)!"
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Header

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)

                    Text(greeting)
                        .font(AppTypography.displayLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Enter your phone number to get started")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxxl)
                }
                .accessibilityElement(children: .combine)

                Spacer()
                    .frame(height: Spacing.xxxl)

                // MARK: - Phone Input

                VStack(spacing: Spacing.lg) {
                    HStack(spacing: 0) {
                        // Country code button
                        Button {
                            HapticManager.lightTap()
                            showCountryPicker = true
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Text(viewModel.selectedCountry.flag)
                                    .font(.system(size: IconSize.md))

                                Text(viewModel.selectedCountry.dialCode)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: IconSize.xs))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                        .accessibilityLabel("\(viewModel.selectedCountry.name), \(viewModel.selectedCountry.dialCode)")
                        .accessibilityHint("Double tap to change country code")

                        // Divider between code and number
                        Rectangle()
                            .fill(AppColors.divider)
                            .frame(width: 1)
                            .padding(.vertical, Spacing.sm)

                        // Phone number text field
                        TextField("Phone number", text: Binding(
                            get: { viewModel.formattedDisplayNumber },
                            set: { newValue in
                                viewModel.phoneNumber = newValue.filter(\.isNumber)
                            }
                        ))
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .padding(.horizontal, Spacing.md)
                            .accessibilityLabel("Phone number")
                            .accessibilityHint("Enter your phone number without the country code")
                            .onChange(of: viewModel.phoneNumber) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                if digits.count > 15 {
                                    viewModel.phoneNumber = String(digits.prefix(15))
                                }
                            }
                    }
                    .frame(height: ButtonHeight.input)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.surface)
                    )
                    .padding(.horizontal, Spacing.xl)

                    // MARK: - Error Message

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.negative)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                            .transition(.opacity)
                    }

                    // MARK: - Continue Button

                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(AppColors.accent)
                            .frame(height: ButtonHeight.lg)
                            .accessibilityLabel("Submitting phone number")
                    } else {
                        Button {
                            HapticManager.tap()
                            Task {
                                await viewModel.submitPhone(context: viewContext)
                            }
                        } label: {
                            Text("Continue")
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isPhoneValid && !viewModel.isSubmitting))
                        .disabled(!viewModel.isPhoneValid || viewModel.isSubmitting)
                        .padding(.horizontal, Spacing.xl)
                        .accessibilityHint(viewModel.isPhoneValid ? "Double tap to submit your phone number" : "Enter a valid phone number first")
                    }
                }

                Spacer()
            }
        }
        .animation(AppAnimation.standard, value: viewModel.isSubmitting)
        .animation(AppAnimation.standard, value: viewModel.errorMessage)
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePicker(selectedCountry: $viewModel.selectedCountry)
        }
    }
}
