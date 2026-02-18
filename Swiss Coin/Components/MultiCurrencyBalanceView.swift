//
//  MultiCurrencyBalanceView.swift
//  Swiss Coin
//
//  Reusable SwiftUI component for displaying multi-currency balances.
//  Three display styles: compact (list rows), expanded (headers), toolbar (nav bar).
//

import SwiftUI

struct MultiCurrencyBalanceView: View {
    let balance: CurrencyBalance
    let style: DisplayStyle
    var personName: String? = nil

    enum DisplayStyle {
        case compact
        case expanded
        case toolbar
    }

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .expanded:
            expandedView
        case .toolbar:
            toolbarView
        }
    }

    // MARK: - Compact Style (List Rows)

    @ViewBuilder
    private var compactView: some View {
        let sorted = balance.sortedCurrencies

        if sorted.isEmpty {
            Text("settled up")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.neutral)
        } else if sorted.count == 1 {
            let entry = sorted[0]
            compactSingleLine(amount: entry.amount, currencyCode: entry.code)
        } else {
            // Multi-currency: show primary + "+N more" badge
            let primary = sorted[0]
            HStack(spacing: Spacing.xs) {
                compactSingleLine(amount: primary.amount, currencyCode: primary.code)

                Text("+\(sorted.count - 1) more")
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
            }
        }
    }

    @ViewBuilder
    private func compactSingleLine(amount: Double, currencyCode: String) -> some View {
        let formatted = CurrencyFormatter.formatAbsolute(amount, currencyCode: currencyCode)

        if amount > 0.01 {
            (Text("owes you ") + Text(formatted).fontWeight(.bold))
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.positive)
        } else if amount < -0.01 {
            (Text("you owe ") + Text(formatted).fontWeight(.bold))
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.negative)
        } else {
            Text("settled up")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.neutral)
        }
    }

    // MARK: - Expanded Style (Balance Header)

    @ViewBuilder
    private var expandedView: some View {
        let sorted = balance.sortedCurrencies

        if sorted.isEmpty {
            Text("All settled up!")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.neutral)
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(sorted, id: \.code) { entry in
                    expandedLine(amount: entry.amount, currencyCode: entry.code)
                }
            }
        }
    }

    @ViewBuilder
    private func expandedLine(amount: Double, currencyCode: String) -> some View {
        let flag = CurrencyFormatter.flag(for: currencyCode)
        let formatted = CurrencyFormatter.formatAbsolute(amount, currencyCode: currencyCode)
        let name = personName ?? "They"

        HStack(spacing: Spacing.sm) {
            Text(flag)
                .font(AppTypography.bodyLarge())

            if amount > 0.01 {
                (Text("\(name) owes you ") + Text(formatted).fontWeight(.bold))
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.positive)
            } else if amount < -0.01 {
                (Text("You owe \(name) ") + Text(formatted).fontWeight(.bold))
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.negative)
            }

            Spacer()
        }
    }

    // MARK: - Toolbar Style (Navigation Bar)

    @ViewBuilder
    private var toolbarView: some View {
        let sorted = balance.sortedCurrencies

        if sorted.isEmpty {
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("settled")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.neutral)
            }
        } else if sorted.count == 1 {
            let entry = sorted[0]
            toolbarSingleCurrency(amount: entry.amount, currencyCode: entry.code)
        } else {
            // Multi-currency toolbar
            let primary = sorted[0]
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(sorted.count) currencies")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatAbsolute(primary.amount, currencyCode: primary.code))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(primary.amount > 0.01 ? AppColors.positive : AppColors.negative)
            }
        }
    }

    @ViewBuilder
    private func toolbarSingleCurrency(amount: Double, currencyCode: String) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            if amount > 0.01 {
                Text("owes you")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatAbsolute(amount, currencyCode: currencyCode))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.positive)
            } else if amount < -0.01 {
                Text("you owe")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatAbsolute(amount, currencyCode: currencyCode))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.negative)
            }
        }
    }
}
