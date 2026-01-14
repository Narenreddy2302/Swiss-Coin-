//
//  SettlementMessageView.swift
//  Swiss Coin
//

import SwiftUI

struct SettlementMessageView: View {
    let settlement: Settlement
    let person: Person

    private var messageText: String {
        let formatted = CurrencyFormatter.format(settlement.amount)

        // Determine the message based on who paid whom
        let fromPersonId = settlement.fromPerson?.id
        let toPersonId = settlement.toPerson?.id

        if CurrentUser.isCurrentUser(fromPersonId) {
            // Current user paid someone
            if toPersonId == person.id {
                return "You paid \(person.firstName) \(formatted)"
            } else {
                // Edge case: settlement to someone else (shouldn't appear in this conversation)
                return "You paid \(settlement.toPerson?.firstName ?? "someone") \(formatted)"
            }
        } else if CurrentUser.isCurrentUser(toPersonId) {
            // Someone paid current user
            if fromPersonId == person.id {
                return "\(person.firstName) paid you \(formatted)"
            } else {
                // Edge case: payment from someone else
                return "\(settlement.fromPerson?.firstName ?? "Someone") paid you \(formatted)"
            }
        } else {
            // Neither party is current user (shouldn't happen in normal flow)
            let fromName = settlement.fromPerson?.firstName ?? "Someone"
            let toName = settlement.toPerson?.firstName ?? "someone"
            return "\(fromName) paid \(toName) \(formatted)"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Text(messageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(UIColor.systemGray5))
            )

            if let note = settlement.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text(settlement.date ?? Date(), style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
