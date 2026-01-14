//
//  BalanceHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct BalanceHeaderView: View {
    let person: Person
    let balance: Double
    let onAvatarTap: () -> Void

    private var balanceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: abs(balance))) ?? "$0.00"

        if balance > 0.01 {
            return "\(person.firstName) owes you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(person.firstName) \(formatted)"
        } else {
            return "All settled up!"
        }
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

    private var balanceBackgroundColor: Color {
        if balance > 0.01 {
            return .green.opacity(0.1)
        } else if balance < -0.01 {
            return .red.opacity(0.1)
        } else {
            return Color(UIColor.tertiarySystemFill)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Avatar and Name
            Button(action: onAvatarTap) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? "#34C759"))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(person.initials)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Text(person.name ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Balance Card
            HStack {
                Spacer()
                Text(balanceText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(balanceColor)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(balanceBackgroundColor)
            )
            .padding(.horizontal, 40)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(UIColor.secondarySystemBackground))
    }
}
