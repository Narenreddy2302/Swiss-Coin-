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
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(title: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.sm, weight: .medium))
                    .foregroundColor(color == AppColors.accent ? AppColors.buttonForeground : color)

                Text(title)
                    .font(AppTypography.bodyBold())
                    .foregroundColor(color == AppColors.accent ? AppColors.buttonForeground : color)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(color == AppColors.accent ? AppColors.buttonBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(color == AppColors.accent ? Color.clear : color.opacity(0.3), lineWidth: 1)
                    )
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