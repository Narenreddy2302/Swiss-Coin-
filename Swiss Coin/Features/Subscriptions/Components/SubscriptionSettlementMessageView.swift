//
//  SubscriptionSettlementMessageView.swift
//  Swiss Coin
//
//  Message view for displaying a settlement in the subscription conversation.
//

import SwiftUI

struct SubscriptionSettlementMessageView: View {
    let settlement: SubscriptionSettlement

    private var messageText: String {
        let formatted = CurrencyFormatter.format(settlement.amount)
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            // Current user paid someone
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "You paid \(toName) \(formatted)"
        } else if CurrentUser.isCurrentUser(toPersonId) {
            // Someone paid current user
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            return "\(fromName) paid you \(formatted)"
        } else {
            // Neither party is current user
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "\(fromName) paid \(toName) \(formatted)"
        }
    }

    var body: some View {
        SystemMessageView(
            icon: "checkmark.circle.fill",
            iconColor: AppColors.positive,
            messageText: messageText,
            noteText: settlement.note,
            date: settlement.date,
            backgroundColor: AppColors.settlementBackground
        )
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
