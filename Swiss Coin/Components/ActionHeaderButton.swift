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
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTypography.bodyBold())
                    .foregroundColor(color)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(color == AppColors.accent ? AppColors.accent.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.buttonPress, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

struct ActionHeaderButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.md) {
            // Selected state
            ActionHeaderButton(
                title: "Personal",
                icon: "person.fill",
                color: AppColors.accent
            ) {
                print("Personal tapped")
            }
            
            // Unselected state
            ActionHeaderButton(
                title: "Shared",
                icon: "person.2.fill",
                color: AppColors.textSecondary
            ) {
                print("Shared tapped")
            }
        }
        .padding()
        .background(AppColors.backgroundSecondary)
        .previewLayout(.sizeThatFits)
    }
}