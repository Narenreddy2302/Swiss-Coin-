//
//  ConversationAvatarView.swift
//  Swiss Coin
//
//  Small circle avatar with initials for inline use in conversation items.
//

import SwiftUI

struct ConversationAvatarView: View {
    let initials: String
    let colorHex: String
    var size: CGFloat = AvatarSize.xs

    private var color: Color {
        Color(hex: colorHex)
    }

    var body: some View {
        Circle()
            .fill(color.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(color)
            )
    }
}
