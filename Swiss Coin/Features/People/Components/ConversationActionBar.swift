//
//  ConversationActionBar.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationActionBar: View {
    let balance: Double
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    private var canRemind: Bool {
        balance > 0.01 // Only show remind when they owe you
    }

    var body: some View {
        StandardActionBar(
            balance: balance,
            canRemind: canRemind,
            onAdd: onAdd,
            onSettle: onSettle,
            onRemind: onRemind
        )
    }
}
