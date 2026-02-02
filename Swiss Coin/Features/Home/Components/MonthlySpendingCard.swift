//
//  MonthlySpendingCard.swift
//  Swiss Coin
//
//  Monthly spending summary card showing total paid, total owed,
//  transaction count, and month-over-month comparison.
//

import CoreData
import SwiftUI

struct MonthlySpendingCard: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch ALL transactions (we filter in computed properties)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)],
        animation: .default)
    private var allTransactions: FetchedResults<FinancialTransaction>

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    private var currentMonthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: comps) ?? Date()
    }

    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? Date()
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Current Month Data

    private var currentMonthTransactions: [FinancialTransaction] {
        allTransactions.filter { tx in
            guard let date = tx.date else { return false }
            return date >= currentMonthStart
        }
    }

    private var totalPaidThisMonth: Double {
        currentMonthTransactions
            .filter { CurrentUser.isCurrentUser($0.payer?.id) }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalOwedThisMonth: Double {
        currentMonthTransactions.reduce(0) { total, tx in
            let splits = tx.splits as? Set<TransactionSplit> ?? []
            let myOwed = splits
                .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
                .reduce(0) { $0 + $1.amount }
            return total + myOwed
        }
    }

    private var transactionCountThisMonth: Int {
        currentMonthTransactions.count
    }

    // MARK: - Previous Month Data (for comparison)

    private var previousMonthTransactions: [FinancialTransaction] {
        allTransactions.filter { tx in
            guard let date = tx.date else { return false }
            return date >= previousMonthStart && date < currentMonthStart
        }
    }

    private var totalPaidLastMonth: Double {
        previousMonthTransactions
            .filter { CurrentUser.isCurrentUser($0.payer?.id) }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Comparison

    private var comparisonText: String? {
        guard totalPaidLastMonth > 0.01 else { return nil }
        let change = ((totalPaidThisMonth - totalPaidLastMonth) / totalPaidLastMonth) * 100
        let absChange = Int(abs(change))
        if change > 1 {
            return "↑ \(absChange)% vs last month"
        } else if change < -1 {
            return "↓ \(absChange)% vs last month"
        } else {
            return "≈ Same as last month"
        }
    }

    private var comparisonColor: Color {
        guard totalPaidLastMonth > 0.01 else { return AppColors.neutral }
        let change = totalPaidThisMonth - totalPaidLastMonth
        if change > 0.01 { return AppColors.negative }
        else if change < -0.01 { return AppColors.positive }
        else { return AppColors.neutral }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header: month name
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.accent)

                Text(currentMonthName)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(transactionCountThisMonth) transaction\(transactionCountThisMonth == 1 ? "" : "s")")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Amounts row
            HStack(spacing: Spacing.xl) {
                // Total Paid
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("You Paid")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    Text(CurrencyFormatter.format(totalPaidThisMonth))
                        .font(AppTypography.amount())
                        .foregroundColor(AppColors.textPrimary)
                }

                // Divider
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(width: 1, height: 36)

                // Total Owed
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("You Owe")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    Text(CurrencyFormatter.format(totalOwedThisMonth))
                        .font(AppTypography.amount())
                        .foregroundColor(AppColors.negative)
                }

                Spacer()
            }

            // Month-over-month comparison
            if let comparison = comparisonText {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(comparisonColor)
                        .frame(width: 6, height: 6)

                    Text(comparison)
                        .font(AppTypography.caption())
                        .foregroundColor(comparisonColor)
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
