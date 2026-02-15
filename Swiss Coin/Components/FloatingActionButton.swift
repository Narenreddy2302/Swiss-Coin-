//
//  FloatingActionButton.swift
//  Swiss Coin
//
//  Floating Action Button (FAB) component for quick actions.
//

import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.tap()
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: IconSize.lg, weight: .semibold))
                .foregroundColor(AppColors.onAccent)
                .frame(width: ButtonHeight.xl, height: ButtonHeight.xl)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppColors.accent,
                                    AppColors.accent.opacity(0.85)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: AppColors.accent.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add transaction")
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton {
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}
