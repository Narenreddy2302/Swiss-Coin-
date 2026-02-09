//
//  GroupConversationActionBar.swift
//  Swiss Coin
//
//  Action bar for group conversation views.
//  Uses unified ActionBarButton component for consistency.
//

import SwiftUI

struct GroupConversationActionBar: View {
    let balance: Double
    let memberBalances: [(member: Person, balance: Double)]
    let membersWhoOweYou: [(member: Person, amount: Double)]
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    /// Enable settle if ANY member has a non-zero balance (not just net group total)
    private var canSettle: Bool {
        memberBalances.contains { abs($0.balance) > 0.01 }
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
