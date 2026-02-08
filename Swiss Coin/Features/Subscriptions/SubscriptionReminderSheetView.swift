//
//  SubscriptionReminderSheetView.swift
//  Swiss Coin
//
//  View for sending payment reminders to members who owe.
//

import CoreData
import SwiftUI

struct SubscriptionReminderSheetView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var selectedMembers: Set<Person> = []
    @State private var message = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var membersWhoOwe: [(member: Person, amount: Double)] {
        subscription.getMembersWhoOweYou()
    }

    private var canSend: Bool {
        !selectedMembers.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Members Selection
                Section {
                    if membersWhoOwe.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.positive)

                            Text("No Reminders Needed")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)

                            Text("No one owes you for this subscription.")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    } else {
                        ForEach(membersWhoOwe, id: \.member.id) { item in
                            Button {
                                HapticManager.selectionChanged()
                                if selectedMembers.contains(item.member) {
                                    selectedMembers.remove(item.member)
                                } else {
                                    selectedMembers.insert(item.member)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(item.member.initials)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hex: item.member.colorHex ?? "#808080"))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.member.firstName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)

                                        (Text("owes ") + Text(CurrencyFormatter.format(item.amount)).fontWeight(.bold))
                                            .font(AppTypography.caption())
                                            .foregroundColor(AppColors.positive)
                                    }

                                    Spacer()

                                    Image(systemName: selectedMembers.contains(item.member) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedMembers.contains(item.member) ? AppColors.accent : AppColors.textSecondary)
                                }
                            }
                        }
                    }
                } header: {
                    if !membersWhoOwe.isEmpty {
                        Text("Select Members")
                            .font(AppTypography.subheadlineMedium())
                    }
                } footer: {
                    if !membersWhoOwe.isEmpty {
                        Button {
                            HapticManager.tap()
                            if selectedMembers.count == membersWhoOwe.count {
                                selectedMembers.removeAll()
                            } else {
                                selectedMembers = Set(membersWhoOwe.map { $0.member })
                            }
                        } label: {
                            Text(selectedMembers.count == membersWhoOwe.count ? "Deselect All" : "Select All")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.top, Spacing.xs)
                    }
                }

                // Custom Message
                if !membersWhoOwe.isEmpty {
                    Section {
                        TextField("Add a message (optional)", text: $message)
                            .limitTextLength(to: ValidationLimits.maxMessageLength, text: $message)
                    } header: {
                        Text("Message")
                            .font(AppTypography.subheadlineMedium())
                    } footer: {
                        Text("This message will be included with the reminder.")
                            .font(AppTypography.caption())
                    }
                }

                // Preview
                if !selectedMembers.isEmpty {
                    Section {
                        ForEach(Array(selectedMembers)) { member in
                            if let item = membersWhoOwe.first(where: { $0.member.id == member.id }) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(AppColors.warning)

                                    (Text("\(member.firstName) - ") + Text(CurrencyFormatter.format(item.amount)).fontWeight(.bold))
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                    } header: {
                        Text("Reminders to Send")
                            .font(AppTypography.subheadlineMedium())
                    }
                }
            }
            .navigationTitle("Send Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendReminders()
                    }
                    .disabled(!canSend)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func sendReminders() {
        HapticManager.save()

        for member in selectedMembers {
            if let item = membersWhoOwe.first(where: { $0.member.id == member.id }) {
                let reminder = SubscriptionReminder(context: viewContext)
                reminder.id = UUID()
                reminder.createdDate = Date()
                reminder.amount = item.amount
                reminder.message = message.isEmpty ? nil : message
                reminder.isRead = false
                reminder.toPerson = member
                reminder.subscription = subscription
            }
        }

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to send reminders: \(error.localizedDescription)"
            showingError = true
        }
    }
}
