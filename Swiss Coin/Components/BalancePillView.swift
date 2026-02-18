//
//  BalancePillView.swift
//  Swiss Coin
//
//  Pill-shaped balance badge for conversation headers.
//

import SwiftUI

struct BalancePillView: View {
    let balance: CurrencyBalance
    var prefixText: String? = nil

    var body: some View {
        let sorted = balance.sortedCurrencies

        HStack(spacing: Spacing.xs) {
            if let prefixText {
                Text(prefixText)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            pillContent(sorted: sorted)

            if sorted.count > 1 {
                Text("+\(sorted.count - 1) more")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func pillContent(sorted: [(code: String, amount: Double)]) -> some View {
        let (text, bgColor, fgColor) = pillAttributes(sorted: sorted)

        Text(text)
            .font(AppTypography.labelSmall())
            .foregroundColor(fgColor)
            .contentTransition(.numericText())
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(
                Capsule()
                    .fill(bgColor)
            )
    }

    private func pillAttributes(sorted: [(code: String, amount: Double)]) -> (String, Color, Color) {
        if sorted.isEmpty {
            return ("Settled up", AppColors.neutralMuted, AppColors.neutral)
        }

        let entry = sorted[0]
        if entry.amount > 0.01 {
            let amount = CurrencyFormatter.formatAbsolute(entry.amount, currencyCode: entry.code)
            return ("Owes you \(amount)", AppColors.positiveMuted, AppColors.positive)
        } else {
            let amount = CurrencyFormatter.formatAbsolute(entry.amount, currencyCode: entry.code)
            return ("You owe \(amount)", AppColors.negativeMuted, AppColors.negative)
        }
    }
}
