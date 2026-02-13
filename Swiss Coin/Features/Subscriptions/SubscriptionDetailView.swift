//
//  SubscriptionDetailView.swift
//  Swiss Coin
//
//  Detail view for viewing and managing a subscription.
//

import CoreData
import SwiftUI
import UIKit

struct SubscriptionDetailView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingArchiveAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    var body: some View {
        List {
            // Header Section with icon and amount
            Section {
                VStack(spacing: Spacing.lg) {
                    // Large Icon
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                        .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                        .overlay(
                            Image(systemName: subscription.iconName ?? "creditcard.fill")
                                .font(.system(size: IconSize.xl))
                                .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                        )

                    // Name
                    Text(subscription.name ?? "Unknown")
                        .font(AppTypography.displayLarge())
                        .foregroundColor(AppColors.textPrimary)

                    // Amount
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyFormatter.format(subscription.amount))
                            .font(AppTypography.financialLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Text("/\(subscription.cycle ?? "month")")
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Status Pill
                    StatusPill(status: subscription.billingStatus)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            }
            .listRowBackground(Color.clear)

            // Billing Info Section
            Section {
                LabeledContent("Next Payment") {
                    Text(subscription.nextBillingDate?.formatted(.dateTime.month().day().year()) ?? "Unknown")
                        .foregroundColor(AppColors.textSecondary)
                }

                LabeledContent("Billing Cycle") {
                    Text(subscription.cycle ?? "Monthly")
                        .foregroundColor(AppColors.textSecondary)
                }

                LabeledContent("Start Date") {
                    Text(subscription.startDate?.formatted(.dateTime.month().day().year()) ?? "Unknown")
                        .foregroundColor(AppColors.textSecondary)
                }

                if let category = subscription.category, !category.isEmpty {
                    LabeledContent("Category") {
                        Text(category)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } header: {
                Text("Billing")
                    .font(AppTypography.labelLarge())
            }

            // Cost Breakdown Section
            Section {
                LabeledContent("Monthly") {
                    Text(CurrencyFormatter.format(subscription.monthlyEquivalent))
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textSecondary)
                }

                LabeledContent("Yearly") {
                    Text(CurrencyFormatter.format(subscription.yearlyEquivalent))
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textSecondary)
                }

                if subscription.isShared {
                    LabeledContent("Your Share") {
                        Text(CurrencyFormatter.format(subscription.myShare))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accent)
                    }
                }
            } header: {
                Text("Cost Summary")
                    .font(AppTypography.labelLarge())
            }

            // Members Section (for shared subscriptions)
            if subscription.isShared {
                Section {
                    let members = subscription.subscribers as? Set<Person> ?? []
                    ForEach(Array(members).sorted { ($0.name ?? "") < ($1.name ?? "") }) { member in
                        HStack(spacing: Spacing.md) {
                            Circle()
                                .fill(Color(hex: member.colorHex ?? "#808080").opacity(0.3))
                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                .overlay(
                                    Text(member.initials)
                                        .font(AppTypography.labelSmall())
                                        .foregroundColor(Color(hex: member.colorHex ?? "#808080"))
                                )

                            Text(member.displayName)
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            let balance = subscription.calculateBalanceWith(member: member)
                            if abs(balance) > 0.01 {
                                (balance > 0
                                    ? Text("owes you ") + Text(CurrencyFormatter.formatAbsolute(balance)).fontWeight(.bold)
                                    : Text("you owe ") + Text(CurrencyFormatter.formatAbsolute(abs(balance))).fontWeight(.bold))
                                    .font(AppTypography.bodyDefault())
                                    .foregroundColor(balance > 0 ? AppColors.positive : AppColors.negative)
                            } else {
                                Text("settled")
                                    .font(AppTypography.bodyDefault())
                                    .foregroundColor(AppColors.neutral)
                            }
                        }
                    }

                    if members.isEmpty {
                        Text("No members added")
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("Members (\(subscription.memberCount + 1))")
                        .font(AppTypography.labelLarge())
                }
            }

            // Notifications Section
            Section {
                Toggle("Payment Reminders", isOn: Binding(
                    get: { subscription.notificationEnabled },
                    set: { newValue in
                        subscription.notificationEnabled = newValue
                        do {
                            try viewContext.save()
                            HapticManager.toggle()

                            // Schedule or cancel notification
                            if newValue {
                                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
                            } else {
                                NotificationManager.shared.cancelSubscriptionReminder(for: subscription)
                            }
                        } catch {
                            viewContext.rollback()
                            HapticManager.error()
                            errorMessage = "Failed to update notification setting: \(error.localizedDescription)"
                            showingError = true
                        }
                    }
                ))

                if subscription.notificationEnabled {
                    Stepper(
                        "\(subscription.notificationDaysBefore) days before",
                        value: Binding(
                            get: { Int(subscription.notificationDaysBefore) },
                            set: { newValue in
                                subscription.notificationDaysBefore = Int16(newValue)
                                do {
                                    try viewContext.save()

                                    // Reschedule with updated days-before value
                                    NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
                                } catch {
                                    viewContext.rollback()
                                    HapticManager.error()
                                    errorMessage = "Failed to update reminder days: \(error.localizedDescription)"
                                    showingError = true
                                }
                            }
                        ),
                        in: 1...14
                    )
                }
            } header: {
                Text("Notifications")
                    .font(AppTypography.labelLarge())
            }

            // Payment History Section
            Section {
                let payments = subscription.recentPayments.prefix(5)
                if payments.isEmpty {
                    Text("No payments recorded")
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(Array(payments)) { payment in
                        PaymentHistoryRow(payment: payment)
                    }
                }
            } header: {
                Text("Recent Payments")
                    .font(AppTypography.labelLarge())
            }

            // Notes Section
            if let notes = subscription.notes, !notes.isEmpty {
                Section {
                    Text(notes)
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textSecondary)
                } header: {
                    Text("Notes")
                        .font(AppTypography.labelLarge())
                }
            }

            // Actions Section
            Section {
                VStack(spacing: Spacing.sm) {
                    Button {
                        HapticManager.tap()
                        showingEditSheet = true
                    } label: {
                        Text("Edit Subscription")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        HapticManager.tap()
                        togglePauseStatus()
                    } label: {
                        Text(subscription.isActive ? "Pause Subscription" : "Resume Subscription")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        HapticManager.tap()
                        if subscription.isArchived {
                            restoreSubscription()
                        } else {
                            showingArchiveAlert = true
                        }
                    } label: {
                        Text(subscription.isArchived ? "Restore Subscription" : "Archive Subscription")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        HapticManager.tap()
                        showingDeleteAlert = true
                    } label: {
                        Text("Cancel Subscription")
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
                .padding(.vertical, Spacing.sm)
            }
            .listRowBackground(Color.clear)

        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            EditSubscriptionView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Cancel Subscription", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSubscription()
            }
        } message: {
            Text("Are you sure you want to cancel this subscription? This action cannot be undone.")
        }
        .alert("Archive Subscription", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive) {
                archiveSubscription()
            }
        } message: {
            Text("This subscription will be moved to the archive. You can restore it later from the archived subscriptions list.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func togglePauseStatus() {
        subscription.isActive.toggle()
        do {
            try viewContext.save()

            // Reschedule or cancel notification based on active state
            if subscription.isActive && subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            } else {
                NotificationManager.shared.cancelSubscriptionReminder(for: subscription)
            }

            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to update subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func archiveSubscription() {
        subscription.isArchived = true
        subscription.isActive = false  // Deactivate when archiving
        do {
            try viewContext.save()

            // Cancel any pending notification when archiving
            NotificationManager.shared.cancelSubscriptionReminder(for: subscription)

            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to archive subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func restoreSubscription() {
        subscription.isArchived = false
        subscription.isActive = true  // Reactivate when restoring
        do {
            try viewContext.save()

            // Reschedule notification if enabled
            if subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }

            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to restore subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteSubscription() {
        HapticManager.delete()

        // Cancel any pending notification before deleting
        NotificationManager.shared.cancelSubscriptionReminder(for: subscription)

        viewContext.delete(subscription)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

}

// MARK: - Payment History Row

struct PaymentHistoryRow: View {
    let payment: SubscriptionPayment

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isUserPayer ? "You paid" : "\(payment.payer?.firstName ?? "Someone") paid")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(payment.date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(CurrencyFormatter.format(payment.amount))
                .font(AppTypography.financialSmall())
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

