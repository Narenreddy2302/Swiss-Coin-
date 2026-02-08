//
//  SettlementMessageView.swift
//  Swiss Coin
//
//  System message for settlements in person conversations.
//

import SwiftUI

struct SettlementMessageView: View {
    let settlement: Settlement
    let person: Person

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
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.positive)

                Text(messageText)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.cardBackground)
            )

            if let note = settlement.note, !note.isEmpty {
                Text(note)
                    .font(AppTypography.caption2())
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }

            Text(settlement.date ?? Date(), style: .date)
                .font(AppTypography.caption2())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
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
