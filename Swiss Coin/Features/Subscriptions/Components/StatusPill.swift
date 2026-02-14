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
                .font(.system(size: IconSize.xs, weight: .medium))

            Text(status.label)
                .font(AppTypography.labelLarge())
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
