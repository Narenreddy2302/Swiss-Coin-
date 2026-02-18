//
//  ConversationActionBar.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationActionBar: View {
    let canSettle: Bool
    let canRemind: Bool
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    var body: some View {
        StandardActionBar(
            canSettle: canSettle,
            canRemind: canRemind,
            onAdd: onAdd,
            onSettle: onSettle,
            onRemind: onRemind
        )
    }
}
