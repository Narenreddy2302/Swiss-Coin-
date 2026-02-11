//
//  SettlementMessageView.swift
//  Swiss Coin
//
//  Timeline-style system message for settlements in person conversations.
//

import SwiftUI

struct SettlementMessageView: View {
    let settlement: Settlement
    let person: Person
    var onCopy: (() -> Void)? = nil
    var onCopyAmount: (() -> Void)? = nil

    private var messageText: String {
        let formatted = CurrencyFormatter.format(settlement.amount)
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            if toPersonId == person.id {
                return "You paid \(person.firstName) \(formatted)"
            } else {
                return "You paid \(settlement.toPerson?.firstName ?? "someone") \(formatted)"
            }
        } else if CurrentUser.isCurrentUser(toPersonId) {
            if fromPersonId == person.id {
                return "\(person.firstName) paid you \(formatted)"
            } else {
                return "\(settlement.fromPerson?.firstName ?? "Someone") paid you \(formatted)"
            }
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
            backgroundColor: AppColors.positiveMuted
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu {
            Button {
                onCopy?()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                onCopyAmount?()
            } label: {
                Label("Copy Amount", systemImage: "dollarsign.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Settlement: \(messageText)")
    }
}
