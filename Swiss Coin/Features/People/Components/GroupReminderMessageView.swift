//
//  GroupReminderMessageView.swift
//  Swiss Coin
//
//  Centered pill notification for reminders in group conversations.
//

import SwiftUI

struct GroupReminderMessageView: View {
    let reminder: Reminder

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        let personName = reminder.toPerson?.firstName ?? "Someone"
        return "Reminder sent to \(personName) for \(formatted)"
    }

    var body: some View {
        SystemMessageView(
            icon: "bell.fill",
            iconColor: AppColors.warning,
            messageText: messageText,
            noteText: reminder.message.flatMap { $0.isEmpty ? nil : "\"\($0)\"" },
            date: reminder.createdDate,
            backgroundColor: AppColors.reminderBackground
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
                UIPasteboard.general.string = CurrencyFormatter.format(reminder.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "dollarsign.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder: \(messageText)")
    }
}
