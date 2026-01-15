//
//  EmptySubscriptionView.swift
//  Swiss Coin
//
//  Empty state view for subscription lists.
//

import SwiftUI

struct EmptySubscriptionView: View {
    let isShared: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: isShared ? "person.2.circle" : "creditcard")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Text(isShared ? "No Shared Subscriptions" : "No Subscriptions")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            Text(isShared
                 ? "Add a shared subscription to split costs with friends and family"
                 : "Track your recurring payments and never miss a billing date")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            // Hint
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Tap + to add your first subscription")
                    .font(AppTypography.subheadline())
            }
            .foregroundColor(AppColors.accent)
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}
