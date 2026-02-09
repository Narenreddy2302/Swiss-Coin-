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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.positive)

                Text(messageText)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.positiveMuted)
            )

            if let note = settlement.note, !note.isEmpty {
                Text(note)
                    .captionStyle()
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
                    .padding(.leading, Spacing.xs)
            }

            Text(settlement.date ?? Date(), style: .date)
                .captionStyle()
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
