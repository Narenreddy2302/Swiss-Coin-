//
//  ConversationActionBar.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationActionBar: View {
    let balance: Double
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    private var canRemind: Bool {
        balance > 0.01 // Only show remind when they owe you
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Add Transaction Button (Primary - Green Accent)
            ActionButton(
                title: "Add",
                icon: "plus",
                isPrimary: true,
                isEnabled: true,
                action: onAdd
            )

            // Remind Button
            ActionButton(
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
            ActionButton(
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

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled || isPrimary {
                HapticManager.buttonPress()
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                if isPrimary {
                    // Green circle with plus icon for Add button
                    ZStack {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: IconSize.lg, height: IconSize.lg)

                        Image(systemName: icon)
                            .font(.system(size: IconSize.xs, weight: .bold))
                            .foregroundColor(.black)
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
        }
        .buttonStyle(AppButtonStyle(haptic: .none)) // Haptic handled in action
        .disabled(!isEnabled && !isPrimary)
    }
}
