//
//  SubscriptionInfoCard.swift
//  Swiss Coin
//
//  Info card displayed at the top of shared subscription conversation.
//  Compact billing info pill: amount, cycle, status.
//

import SwiftUI

struct SubscriptionInfoCard: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(CurrencyFormatter.format(subscription.amount))
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.textPrimary)

            Text("/\(subscription.cycleAbbreviation)")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            Text("\u{00B7}")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)

            Text(subscription.cycle ?? "Monthly")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            Text("\u{00B7}")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)

            Text(statusText)
                .font(AppTypography.labelSmall())
                .foregroundColor(subscription.billingStatus.color)

            Spacer()
        }
        .cardStyle()
    }

    private var statusText: String {
        let status = subscription.billingStatus
        switch status {
        case .overdue: return "Overdue"
        case .due:
            let days = subscription.daysUntilNextBilling
            if days == 0 { return "Due today" }
            else if days == 1 { return "Due tomorrow" }
            else { return "Due in \(days)d" }
        case .upcoming:
            if let date = subscription.nextBillingDate {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
            return "Upcoming"
        case .paused: return "Paused"
        }
    }
}
