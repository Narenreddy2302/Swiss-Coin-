//
//  ConversationHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationHeaderView: View {
    let person: Person
    let balance: Double
    let onAvatarTap: () -> Void

    private var balanceLabel: String {
        if balance > 0.01 {
            return "owes you"
        } else if balance < -0.01 {
            return "you owe"
        } else {
            return "settled"
        }
    }

    private var balanceAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: abs(balance))) ?? "$0.00"
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return .green
        } else if balance < -0.01 {
            return .red
        } else {
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar and Name (left side)
            Button(action: onAvatarTap) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? "#34C759"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(person.initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text(person.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Balance (right side)
            VStack(alignment: .trailing, spacing: 2) {
                Text(balanceLabel)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)

                Text(balanceAmount)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }
}
