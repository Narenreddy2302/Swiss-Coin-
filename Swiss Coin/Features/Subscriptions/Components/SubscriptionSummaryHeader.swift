//
//  SubscriptionSummaryHeader.swift
//  Swiss Coin
//
//  Context-aware summary card shown at the top of subscription lists.
//  Adapts content based on isShared parameter.
//

import SwiftUI

struct SubscriptionSummaryHeader: View {
    let isShared: Bool
    let subscriptions: [Subscription]

    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.isActive }
    }

    private var activeCount: Int {
        activeSubscriptions.count
    }

    private var monthlyTotal: Double {
        activeSubscriptions.reduce(0) { total, sub in
            total + sub.monthlyEquivalent
        }
    }

    // Shared-specific: user's share of the total
    private var userMonthlyShare: Double {
        activeSubscriptions.reduce(0) { total, sub in
            let memberTotal = sub.memberCount + 1
            guard memberTotal > 0 else { return total }
            return total + (sub.monthlyEquivalent / Double(memberTotal))
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isShared ? "Your Monthly Share" : "Monthly Cost")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.format(isShared ? userMonthlyShare : monthlyTotal))
                    .font(AppTypography.financialLarge())
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(activeCount)")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.accent.opacity(0.12))
                    )

                Text(isShared ? "shared\nsubs" : "active\nsubs")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .cardStyle()
        .padding(.horizontal, Spacing.lg)
    }
}
