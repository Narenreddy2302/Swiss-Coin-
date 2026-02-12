//
//  SubscriptionSettlementMessageView.swift
//  Swiss Coin
//
//  Full-width green notification strip for settlements in subscription conversations.
//

import SwiftUI

struct SubscriptionSettlementMessageView: View {
    let settlement: SubscriptionSettlement

    private var messageText: String {
        let formatted = CurrencyFormatter.format(settlement.amount)
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "You paid \(toName) \(formatted)"
        } else if CurrentUser.isCurrentUser(toPersonId) {
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            return "\(fromName) paid you \(formatted)"
        } else {
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "\(fromName) paid \(toName) \(formatted)"
        }
    }

    var body: some View {
        SystemMessageView(
            icon: "checkmark.circle.fill",
            iconColor: AppColors.stripText,
            messageText: messageText,
            noteText: settlement.note,
            date: settlement.date,
            backgroundColor: AppColors.settlementStripBackground
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu {
            Button {
                UIPasteboard.general.string = messageText
                HapticManager.copyAction()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(settlement.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "dollarsign.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Settlement: \(messageText)")
    }
}
