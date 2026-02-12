//
//  ActionBarButton.swift
//  Swiss Coin
//
//  Unified action bar button component for consistent styling across the app.
//  Used in conversation views and group chats.
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
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
        .background(AppColors.backgroundSecondary)
        .onAppear {
            HapticManager.prepare()
        }
    }
}

// MARK: - Standard Action Bar

/// Standard three-button action bar used across person and group conversations
struct StandardActionBar: View {
    let balance: Double
    let canRemind: Bool
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void
    
    private var canSettle: Bool {
        abs(balance) > 0.01
    }

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
            balance: 50.0,
            canRemind: true,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
        
        // Disabled state
        StandardActionBar(
            balance: 0,
            canRemind: false,
            onAdd: {},
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
            balance: 50.0,
            canRemind: true,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )

        // Disabled state
        StandardActionBar(
            balance: 0,
            canRemind: false,
            onAdd: {},
            onSettle: {},
            onRemind: {}
        )
    }
    .background(AppColors.backgroundSecondary)
    .preferredColorScheme(.dark)
}
