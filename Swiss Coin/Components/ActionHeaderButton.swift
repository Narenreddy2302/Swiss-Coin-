//
//  ActionHeaderButton.swift
//  Swiss Coin
//
//  Reusable header button component for segmented-style navigation.
//  Used in SubscriptionView and other views for consistent styling.
//

import SwiftUI

struct ActionHeaderButton: View {
    let title: String
    let icon: String
    let color: Color
    let expand: Bool
    let compact: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(title: String, icon: String, color: Color, expand: Bool = true, compact: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.expand = expand
        self.compact = compact
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? Spacing.xs : Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: compact ? IconSize.xs : IconSize.sm, weight: .medium))
                    .foregroundColor(color == AppColors.accent ? AppColors.buttonForeground : color)

                Text(title)
                    .font(compact ? AppTypography.buttonSmall() : AppTypography.buttonDefault())
                    .foregroundColor(color == AppColors.accent ? AppColors.buttonForeground : color)
            }
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg)
            .padding(.vertical, compact ? Spacing.sm : Spacing.md)
            .frame(maxWidth: expand ? .infinity : nil)
            .fixedSize(horizontal: !expand, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(color == AppColors.accent ? AppColors.buttonBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(color == AppColors.accent ? Color.clear : AppColors.border, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.buttonPress, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.md) {
        // Selected state
        ActionHeaderButton(
            title: "Personal",
            icon: "person.fill",
            color: AppColors.accent
        ) {
            // Preview action
        }
        
        // Unselected state
        ActionHeaderButton(
            title: "Shared",
            icon: "person.2.fill",
            color: AppColors.textSecondary
        ) {
            // Preview action
        }
    }
    .padding()
    .background(AppColors.backgroundSecondary)
}