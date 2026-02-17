//
//  MemberChip.swift
//  Swiss Coin
//
//  A chip view for displaying selected members in subscription forms.
//

import SwiftUI

struct MemberChip: View {
    let person: Person
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Avatar
            ConversationAvatarView(
                initials: person.initials,
                colorHex: person.safeColorHex,
                size: IconSize.category
            )
            
            // Name
            Text(person.displayName)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            
            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.full)
    }
}