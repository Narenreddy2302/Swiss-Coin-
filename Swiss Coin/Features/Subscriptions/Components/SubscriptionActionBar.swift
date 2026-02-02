//
//  SubscriptionActionBar.swift
//  Swiss Coin
//
//  Action bar for shared subscription conversation view.
//  Uses unified ActionBarButton component for consistency.
//

import SwiftUI

struct SubscriptionActionBar: View {
    let balance: Double
    let membersWhoOwe: [(member: Person, amount: Double)]
    let onRecordPayment: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    var body: some View {
        SubscriptionActionBarView(
            balance: balance,
            membersWhoOwe: membersWhoOwe,
            onRecordPayment: onRecordPayment,
            onSettle: onSettle,
            onRemind: onRemind
        )
    }
}
