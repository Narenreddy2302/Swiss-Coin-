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
        HStack(spacing: Spacing.xxs) {
            Image(systemName: status.icon)
                .font(.system(size: IconSize.xs, weight: .medium))

            Text(status.label)
                .font(AppTypography.labelSmall())
        }
        .foregroundColor(status.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
        )
    }
}
