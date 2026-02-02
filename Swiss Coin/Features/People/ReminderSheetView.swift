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
            VStack(spacing: Spacing.xxl) {
                // Header
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: IconSize.xxl))
                        .foregroundColor(AppColors.warning)

                    Text("Send Reminder")
                        .font(AppTypography.title2())

                    Text("\(person.name?.components(separatedBy: " ").first ?? "They") owe you \(formattedAmount)")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, Spacing.section)

                // Message Field
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Message (optional)")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Add a friendly reminder message...", text: $message, axis: .vertical)
                        .limitTextLength(to: ValidationLimits.maxMessageLength, text: $message)
                        .font(AppTypography.body())
                        .lineLimit(3...6)
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Send Button
                Button {
                    HapticManager.tap()
                    sendReminder()
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.system(size: IconSize.sm))
                        Text("Send Reminder")
                            .font(AppTypography.bodyBold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.lg)
                    .background(AppColors.warning)
                    .cornerRadius(CornerRadius.md)
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xl)
            }
            .background(AppColors.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                HapticManager.prepare()
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
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to send reminder: \(error.localizedDescription)"
            showingError = true
        }
    }
}
