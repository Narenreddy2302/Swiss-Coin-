//
//  UndoToast.swift
//  Swiss Coin
//
//  Floating undo toast for reversible delete actions.
//

import SwiftUI

// MARK: - Undo Toast View

struct UndoToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "trash.fill")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.textSecondary)

            Text(message)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                HapticManager.tap()
                onUndo()
            } label: {
                Text("Undo")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackgroundElevated)
                .shadow(color: AppColors.shadow, radius: 8, y: 4)
        )
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Undo Toast Modifier

struct UndoToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let onUndo: () -> Void
    var autoDismissAfter: TimeInterval = 3.0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowing {
                    UndoToastView(message: message) {
                        isShowing = false
                        onUndo()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, Spacing.xl)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) {
                            withAnimation(AppAnimation.standard) {
                                isShowing = false
                            }
                        }
                    }
                }
            }
            .animation(AppAnimation.spring, value: isShowing)
    }
}

// MARK: - View Extension

extension View {
    func undoToast(
        isShowing: Binding<Bool>,
        message: String,
        onUndo: @escaping () -> Void,
        autoDismissAfter: TimeInterval = 3.0
    ) -> some View {
        modifier(UndoToastModifier(
            isShowing: isShowing,
            message: message,
            onUndo: onUndo,
            autoDismissAfter: autoDismissAfter
        ))
    }
}
