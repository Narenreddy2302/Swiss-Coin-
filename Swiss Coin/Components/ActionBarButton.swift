//
//  ActionBarButton.swift
//  Swiss Coin
//
//  Unified action bar button component for consistent styling across the app.
//  Used in conversation views, group chats, and subscription screens.
//

import SwiftUI

// MARK: - Action Bar Button

/// A professional, consistent action button for action bars.
/// Designed for high visibility in both light and dark modes.
struct ActionBarButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        isPrimary: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isEnabled || isPrimary {
                if isPrimary {
                    HapticManager.primaryAction()
                } else {
                    HapticManager.actionBarTap()
                }
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(AppTypography.buttonDefault())
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.md)
            .padding(.horizontal, Spacing.sm)
            .background(buttonBackground)
            .cornerRadius(CornerRadius.md)
        }
        .buttonStyle(ActionBarPressStyle())
        .disabled(!isEnabled && !isPrimary)
        .opacity(isEnabled || isPrimary ? 1.0 : 0.6)
    }

    // MARK: - Colors

    private var iconColor: Color {
        if isPrimary {
            return AppColors.buttonForeground
        }
        return isEnabled ? AppColors.textPrimary : AppColors.textSecondary
    }

    private var textColor: Color {
        if isPrimary {
            return AppColors.buttonForeground
        }
        return isEnabled ? AppColors.textPrimary : AppColors.textSecondary
    }

    private var buttonBackground: Color {
        if isPrimary {
            return AppColors.buttonBackground
        }
        return isEnabled ? AppColors.backgroundTertiary : AppColors.backgroundTertiary
    }
}

// MARK: - Action Bar Container

/// Standard container for action bar buttons with consistent spacing and background
struct ActionBarContainer<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            content
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.actionBarBackground)
        .onAppear {
            HapticManager.prepare()
        }
    }
}

// MARK: - Standard Action Bar

/// Standard three-button action bar used across person, group, and subscription conversations
struct StandardActionBar: View {
    let canSettle: Bool
    let canRemind: Bool
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    var body: some View {
        ActionBarContainer {
            // Add Button (Always Primary)
            ActionBarButton(
                title: "Add",
                icon: "plus",
                isPrimary: true,
                isEnabled: true,
                action: onAdd
            )

            // Remind Button
            ActionBarButton(
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
            ActionBarButton(
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
    }
}

// MARK: - Subscription Action Bar

/// Premium action bar for subscription conversations with balance summary and refined button styling
struct SubscriptionActionBarView: View {
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

    private var balanceLabel: String {
        if balance > 0.01 { return "you're owed" }
        else if balance < -0.01 { return "you owe" }
        else { return "settled up" }
    }

    private var balanceColor: Color {
        if balance > 0.01 { return AppColors.positive }
        else if balance < -0.01 { return AppColors.negative }
        else { return AppColors.neutral }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hairline top divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 0.5)

            // Balance summary (only when not settled)
            if abs(balance) > 0.01 {
                HStack {
                    Text(balanceLabel)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(CurrencyFormatter.formatAbsolute(balance))
                        .font(AppTypography.financialSmall())
                        .foregroundColor(balanceColor)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xs)
            }

            // Button row
            HStack(spacing: Spacing.sm) {
                // Primary: Record Payment
                ActionBarButton(
                    title: "Pay",
                    icon: "dollarsign.circle.fill",
                    isPrimary: true,
                    isEnabled: true,
                    action: onRecordPayment
                )

                // Secondary outlined: Remind
                outlinedButton(
                    title: "Remind",
                    icon: "bell.fill",
                    isEnabled: canRemind,
                    action: { if canRemind { onRemind() } }
                )

                // Secondary outlined: Settle
                outlinedButton(
                    title: "Settle",
                    icon: "checkmark",
                    isEnabled: canSettle,
                    action: { if canSettle { onSettle() } }
                )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .background(AppColors.actionBarBackground)
        .onAppear { HapticManager.prepare() }
    }

    @ViewBuilder
    private func outlinedButton(
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            if isEnabled {
                HapticManager.actionBarTap()
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.sm, weight: .semibold))

                Text(title)
                    .font(AppTypography.buttonDefault())
            }
            .foregroundColor(isEnabled ? AppColors.textPrimary : AppColors.textDisabled)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.input)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(
                        isEnabled ? AppColors.border : AppColors.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ActionBarPressStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Action Bar Press Style

/// Professional press style with subtle scale + opacity for action bar buttons
private struct ActionBarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    VStack(spacing: Spacing.xl) {
        // Standard Action Bar
        StandardActionBar(
            canSettle: true,
            canRemind: true,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
        
        // Disabled state
        StandardActionBar(
            canSettle: false,
            canRemind: false,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
        
        // Subscription Action Bar
        SubscriptionActionBarView(
            balance: 100.0,
            membersWhoOwe: [],
            onRecordPayment: {},
            onSettle: {},
            onRemind: {}
        )
    }
    .background(AppColors.backgroundSecondary)
}

#Preview("Dark Mode") {
    VStack(spacing: Spacing.xl) {
        // Standard Action Bar
        StandardActionBar(
            canSettle: true,
            canRemind: true,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
        
        // Disabled state
        StandardActionBar(
            canSettle: false,
            canRemind: false,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
        
        // Subscription Action Bar
        SubscriptionActionBarView(
            balance: 100.0,
            membersWhoOwe: [],
            onRecordPayment: {},
            onSettle: {},
            onRemind: {}
        )
    }
    .background(AppColors.backgroundSecondary)
    .preferredColorScheme(.dark)
}
