//
//  ReminderSheetView.swift
//  Swiss Coin
//

import CoreData
import SwiftUI

struct ReminderSheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let person: Person
    let amount: Double

    @State private var message: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var formattedAmount: String {
        CurrencyFormatter.format(amount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Send Reminder")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(person.firstName) owes you \(formattedAmount)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)

                // Message Field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Add a friendly reminder message...", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Send Button
                Button {
                    sendReminder()
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("Send Reminder")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    private func sendReminder() {
        let reminder = Reminder(context: viewContext)
        reminder.id = UUID()
        reminder.createdDate = Date()
        reminder.amount = amount
        reminder.message = message.isEmpty ? nil : message
        reminder.isRead = false
        reminder.isCleared = false
        reminder.toPerson = person

        do {
            try viewContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

            dismiss()
        } catch {
            errorMessage = "Failed to send reminder: \(error.localizedDescription)"
            showingError = true
        }
    }
}
