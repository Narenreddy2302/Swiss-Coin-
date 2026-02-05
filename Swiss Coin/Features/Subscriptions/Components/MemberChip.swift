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
            PersonAvatar(
                initials: person.initials,
                isCurrentUser: false,
                isSelected: false,
                size: 28
            )
            
            // Name
            Text(person.displayName)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            
            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
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

#Preview {
    // Preview requires creating a mock Person in preview context
    // Using a simple text representation for preview purposes
    HStack {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("JD")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                )
            
            Text("John Doe")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.full)
    }
    .padding()
}
