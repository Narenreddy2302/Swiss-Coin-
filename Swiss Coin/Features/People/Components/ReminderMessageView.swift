//
//  ReminderMessageView.swift
//  Swiss Coin
//

import SwiftUI

struct ReminderMessageView: View {
    let reminder: Reminder
    let person: Person

    private var messageText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: reminder.amount)) ?? "$0.00"
        return "Reminder sent for \(formatted)"
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text(messageText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )

            if let message = reminder.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text(reminder.createdDate ?? Date(), style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
