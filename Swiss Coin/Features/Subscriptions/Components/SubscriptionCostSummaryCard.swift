//
//  SubscriptionCostSummaryCard.swift
//  Swiss Coin
//
//  Aggregate cost summary card shown at the top of the Subscriptions tab.
//  Shows total monthly cost, personal vs shared breakdown, and active count.
//

import CoreData
import SwiftUI

struct SubscriptionCostSummaryCard: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch all subscriptions
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)],
        animation: .default)
    private var allSubscriptions: FetchedResults<Subscription>

    // MARK: - Computed Properties

    private var activeSubscriptions: [Subscription] {
        allSubscriptions.filter { $0.isActive }
    }

    private var activeCount: Int {
        activeSubscriptions.count
    }

    /// Total monthly cost across ALL subscriptions (normalized)
    private var totalMonthlyCost: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Personal subscriptions monthly total
    private var personalMonthlyTotal: Double {
        activeSubscriptions
            .filter { !$0.isShared }
            .reduce(0) { $0 + $1.monthlyEquivalent }
    }

    /// Your share of shared subscriptions (monthly equivalent)
    private var sharedMonthlyShare: Double {
        activeSubscriptions
            .filter { $0.isShared }
            .reduce(0) { total, subscription in
                let perCycleShare = subscription.myShare
                switch subscription.cycle {
                case "Weekly":
                    return total + (perCycleShare * 4.33)
                case "Monthly":
                    return total + perCycleShare
                case "Yearly":
                    return total + (perCycleShare / 12.0)
                case "Custom":
                    let days = max(1, Int(subscription.customCycleDays))
                    return total + (perCycleShare * (30.44 / Double(days)))
                default:
                    return total + perCycleShare
                }
            }
    }

    /// Your total monthly cost (personal + your share of shared)
    private var yourTotalMonthly: Double {
        personalMonthlyTotal + sharedMonthlyShare
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Top row: total cost + count
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Total Monthly Cost")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(CurrencyFormatter.format(totalMonthlyCost))
                        .font(AppTypography.amountLarge())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("\(activeCount) active")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(AppColors.accent.opacity(0.12))
                        )

                    Text("subscription\(activeCount == 1 ? "" : "s")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Divider()
                .background(AppColors.textSecondary.opacity(0.2))

            // Breakdown row
            HStack {
                // Personal
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.fill")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Personal")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text(CurrencyFormatter.format(personalMonthlyTotal))
                        .font(AppTypography.amountSmall())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                // Shared (your share)
                VStack(alignment: .center, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Your Share")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text(CurrencyFormatter.format(sharedMonthlyShare))
                        .font(AppTypography.amountSmall())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                // Your total
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sum")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.accent)
                        Text("You Pay")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.accent)
                    }
                    Text(CurrencyFormatter.format(yourTotalMonthly))
                        .font(AppTypography.amountSmall())
                        .foregroundColor(AppColors.accent)
                }
            }

            // Yearly projection
            if totalMonthlyCost > 0 {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: IconSize.xs))
                        .foregroundColor(AppColors.textTertiary)

                    Text("Yearly: \(CurrencyFormatter.format(yourTotalMonthly * 12))")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }
}
