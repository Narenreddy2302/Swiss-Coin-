//
//  GroupSettlementMessageView.swift
//  Swiss Coin
//
//  Centered pill notification for settlements in group conversations.
//

import SwiftUI

struct GroupSettlementMessageView: View {
    let settlement: Settlement
    var onDelete: (() -> Void)? = nil

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
            iconColor: AppColors.positive,
            messageText: messageText,
            noteText: settlement.note,
            date: settlement.date,
            backgroundColor: AppColors.settlementBackground
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

            if let onDelete {
                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Settlement", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Settlement: \(messageText)")
    }
}
