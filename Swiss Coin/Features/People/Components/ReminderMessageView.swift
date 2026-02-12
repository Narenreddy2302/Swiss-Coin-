//
//  ReminderMessageView.swift
//  Swiss Coin
//
//  Timeline-style system message for reminders in person conversations.
//

import SwiftUI

struct ReminderMessageView: View {
    let reminder: Reminder
    var onCopy: (() -> Void)? = nil
    var onCopyAmount: (() -> Void)? = nil

    private var messageText: String {
        let formatted = CurrencyFormatter.format(reminder.amount)
        return "Reminder sent for \(formatted)"
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
        .accessibilityLabel("Reminder: \(messageText)")
    }
}
