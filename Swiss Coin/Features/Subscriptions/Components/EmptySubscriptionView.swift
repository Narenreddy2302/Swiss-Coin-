//
//  EmptySubscriptionView.swift
//  Swiss Coin
//
//  Empty state view for subscription lists.
//

import SwiftUI

struct EmptySubscriptionView: View {
    let isShared: Bool

    var body: some View {
        VStack {
            Spacer()
            Text(isShared ? "No Shared Subscriptions" : "No Subscriptions")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}
