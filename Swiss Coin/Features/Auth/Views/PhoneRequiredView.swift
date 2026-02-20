//
//  PhoneRequiredView.swift
//  Swiss Coin
//
//  Gate view shown when a user tries to create a transaction
//  without a phone number on their profile.
//

import SwiftUI

struct PhoneRequiredView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingPersonalDetails = false

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            Image(systemName: "phone.badge.plus")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.accent)
                .padding(.bottom, Spacing.sm)

            Text("Phone Number Required")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Add your phone number in Profile Settings so others can find and connect with you.")
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                HapticManager.tap()
                showingPersonalDetails = true
            } label: {
                Text("Add Phone Number")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    HapticManager.tap()
                    dismiss()
                }
                .font(AppTypography.bodyLarge())
            }
        }
        .sheet(isPresented: $showingPersonalDetails) {
            NavigationStack {
                PersonalDetailsView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhoneRequiredView()
    }
}
