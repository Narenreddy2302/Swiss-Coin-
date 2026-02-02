//
//  SubscriptionActionBar.swift
//  Swiss Coin
//
//  Action bar for shared subscription conversation view.
//  Matches ConversationActionBar/GroupConversationActionBar pattern.
//

import SwiftUI

struct SubscriptionActionBar: View {
    let balance: Double
    let membersWhoOwe: [(member: Person, amount: Double)]
    let onRecordPayment: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    private var canRemind: Bool {
        !membersWhoOwe.isEmpty
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Record Payment Button (Primary)
            SubscriptionActionButton(
                title: "Pay",
                icon: "dollarsign.circle.fill",
                isPrimary: true,
                isEnabled: true,
                action: onRecordPayment
            )

            // Remind Button
            SubscriptionActionButton(
                title: "Remind",
                icon: "bell.fill",
                isPrimary: false,
                isEnabled: canRemind,
                action: {
                    if canRemind {
                        onRemind()
                    }
                }
            )

            // Settle Button
            SubscriptionActionButton(
                title: "Settle",
                icon: "checkmark",
                isPrimary: false,
                isEnabled: canSettle,
                action: {
                    if canSettle {
                        onSettle()
                    }
                }
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.background)
        .onAppear {
            HapticManager.prepare()
        }
    }
}

// MARK: - Subscription Action Button

private struct SubscriptionActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled || isPrimary {
                HapticManager.tap()
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isPrimary {
                    // Green circle with icon for primary button
                    ZStack {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: IconSize.lg, height: IconSize.lg)

                        Image(systemName: icon)
                            .font(.system(size: IconSize.xs, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundColor(isEnabled ? AppColors.textSecondary : AppColors.disabled)
                }

                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(isPrimary ? AppColors.accent : (isEnabled ? AppColors.textSecondary : AppColors.disabled))
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(AppColors.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(AppButtonStyle(haptic: .none))
        .disabled(!isEnabled && !isPrimary)
    }
}
