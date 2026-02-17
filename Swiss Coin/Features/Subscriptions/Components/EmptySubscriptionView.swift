//
//  EmptySubscriptionView.swift
//  Swiss Coin
//
//  Empty state view for subscription lists with icon, subtitle, and CTA.
//

import SwiftUI

struct EmptySubscriptionView: View {
    let isShared: Bool
    var onAddSubscription: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xxxl)

            // Icon circle
            Circle()
                .fill(AppColors.accentMuted)
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Image(systemName: isShared ? "person.2.circle" : "creditcard.fill")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.accent)
                )

            Spacer()
                .frame(height: Spacing.xxl)

            // Title
            Text(isShared ? "No Shared Subscriptions Yet" : "No Subscriptions Yet")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()
                .frame(height: Spacing.sm)

            // Subtitle
            Text(isShared
                 ? "Split subscriptions with friends and keep track of who owes what."
                 : "Track your recurring payments and never miss a billing date.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Spacer()
                .frame(height: Spacing.xl)

            // CTA button
            if let onAdd = onAddSubscription {
                Button {
                    HapticManager.tap()
                    onAdd()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: IconSize.sm))
                        Text(isShared ? "Add a Shared Subscription" : "Add Your First Subscription")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
                .frame(height: Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(AppColors.backgroundSecondary)
    }
}
