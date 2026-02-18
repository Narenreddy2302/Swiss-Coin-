//
//  InlineSearchBar.swift
//  Swiss Coin
//
//  Reusable inline search bar that scrolls with content,
//  replacing the native .searchable() modifier.
//

import SwiftUI

struct InlineSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.sm, weight: .medium))
                .foregroundColor(AppColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    HapticManager.lightTap()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.searchBarBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5)
        )
        .padding(.horizontal, Spacing.lg)
        .animation(AppAnimation.fast, value: text.isEmpty)
    }
}
