//
//  RefreshFeedbackModifier.swift
//  Swiss Coin
//
//  Reusable view modifier that shows a brief "Updated" indicator after pull-to-refresh.
//

import SwiftUI

struct RefreshFeedbackModifier: ViewModifier {
    @Binding var showUpdated: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showUpdated {
                    Text("Updated")
                        .font(AppTypography.labelSmall())
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.backgroundTertiary)
                                .shadow(color: AppColors.shadowSubtle, radius: 2, x: 0, y: 1)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, Spacing.sm)
                }
            }
            .animation(AppAnimation.standard, value: showUpdated)
    }
}

extension View {
    func refreshFeedback(isShowing: Binding<Bool>) -> some View {
        modifier(RefreshFeedbackModifier(showUpdated: isShowing))
    }
}
