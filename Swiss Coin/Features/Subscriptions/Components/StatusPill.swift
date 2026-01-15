//
//  StatusPill.swift
//  Swiss Coin
//
//  Status indicator pill for subscription billing status.
//

import SwiftUI

struct StatusPill: View {
    let status: BillingStatus

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 12, weight: .medium))

            Text(status.label)
                .font(AppTypography.subheadlineMedium())
        }
        .foregroundColor(status.color)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
    }
}
