//
//  SettlementMessageView.swift
//  Swiss Coin
//

import SwiftUI

struct SettlementMessageView: View {
    let settlement: Settlement
    let person: Person

    private var messageText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: settlement.amount)) ?? "$0.00"

        if settlement.fromPerson?.id == Person.currentUserUUID {
            return "You paid \(person.firstName) \(formatted)"
        } else {
            return "\(person.firstName) paid you \(formatted)"
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
