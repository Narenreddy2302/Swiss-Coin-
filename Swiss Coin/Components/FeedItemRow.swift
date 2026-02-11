//
//  FeedItemRow.swift
//  Swiss Coin
//
//  Generic feed row with avatar, name/timestamp header, and custom content.
//

import SwiftUI

struct FeedItemRow<Content: View>: View {
    let avatarInitials: String
    let avatarColorHex: String
    let name: String
    let timestamp: Date?
    var showDivider: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                ConversationAvatarView(
                    initials: avatarInitials,
                    colorHex: avatarColorHex,
                    size: AvatarSize.sm
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Header: Name + timestamp
                    HStack(spacing: Spacing.xs) {
                        Text(name)
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.textPrimary)

                        if let timestamp {
                            Text("\u{00B7}")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textTertiary)

                            Text(timestamp.relativeShort)
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Spacer()
                    }

                    content()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            if showDivider {
                AppColors.divider
                    .frame(height: 0.5)
                    .padding(.leading, Spacing.rowDividerInset)
            }
        }
    }
}
