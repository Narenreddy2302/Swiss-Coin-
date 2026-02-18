//
//  GroupConversationActionBar.swift
//  Swiss Coin
//
//  Action bar for group conversation views.
//  Uses unified ActionBarButton component for consistency.
//

import SwiftUI

struct GroupConversationActionBar: View {
    let memberBalances: [(member: Person, balance: CurrencyBalance)]
    let membersWhoOweYou: [(member: Person, balance: CurrencyBalance)]
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    /// Enable settle if ANY member has a non-zero balance (not just net group total)
    private var canSettle: Bool {
        memberBalances.contains { !$0.balance.isSettled }
    }

    private var canRemind: Bool {
        !membersWhoOweYou.isEmpty
    }

    var body: some View {
        ActionBarContainer {
            ActionBarButton(
                title: "Add",
                icon: "plus",
                isPrimary: true,
                isEnabled: true,
                action: onAdd
            )

            ActionBarButton(
                title: "Remind",
                icon: "bell.fill",
                isPrimary: false,
                isEnabled: canRemind,
                action: {
                    if canRemind {
                        onRemind()
                    }
                }
            )

            ActionBarButton(
                title: "Settle",
                icon: "checkmark",
                isPrimary: false,
                isEnabled: canSettle,
                action: {
                    if canSettle {
                        onSettle()
                    }
                }
            )
        }
    }
}
