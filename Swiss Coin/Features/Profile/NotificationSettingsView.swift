//
//  NotificationSettingsView.swift
//  Swiss Coin
//
//  View for managing notification preferences.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss

    // Master Toggle
    @AppStorage("notifications_enabled") private var notificationsEnabled = true

    // Transaction Notifications
    @AppStorage("notify_new_expense") private var notifyNewExpense = true
    @AppStorage("notify_expense_modified") private var notifyExpenseModified = true
    @AppStorage("notify_someone_paid") private var notifySomeonePaid = true

    // Reminder Notifications
    @AppStorage("notify_payment_reminders") private var notifyPaymentReminders = true
    @AppStorage("reminder_days_before") private var reminderDaysBefore = 3

    // Subscription Notifications
    @AppStorage("notify_subscription_due") private var notifySubscriptionDue = true
    @AppStorage("subscription_due_days") private var subscriptionDueDays = 3
    @AppStorage("notify_subscription_overdue") private var notifySubscriptionOverdue = true

    // Settlement Notifications
    @AppStorage("notify_settlement_received") private var notifySettlementReceived = true
    @AppStorage("notify_settlement_sent") private var notifySettlementSent = true

    // Group Notifications
    @AppStorage("notify_added_to_group") private var notifyAddedToGroup = true
    @AppStorage("notify_group_expense") private var notifyGroupExpense = true

    // Chat Notifications
    @AppStorage("notify_new_message") private var notifyNewMessage = true

    // Summary Notifications
    @AppStorage("notify_weekly_summary") private var notifyWeeklySummary = true

    // Quiet Hours
    @AppStorage("quiet_hours_enabled") private var quietHoursEnabled = false
    @State private var quietHoursStart = Date()
    @State private var quietHoursEnd = Date()

    var body: some View {
        Form {
            // Master Toggle
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("All Notifications", systemImage: "bell.fill")
                }
                .onChange(of: notificationsEnabled) { _, _ in
                    HapticManager.toggle()
                }
            } footer: {
                Text("Turn off to disable all notifications from Swiss Coin.")
                    .font(AppTypography.caption())
            }

            if notificationsEnabled {
                // Transaction Notifications
                Section {
                    Toggle("New expense added", isOn: $notifyNewExpense)
                        .onChange(of: notifyNewExpense) { _, _ in HapticManager.toggle() }

                    Toggle("Expense modified", isOn: $notifyExpenseModified)
                        .onChange(of: notifyExpenseModified) { _, _ in HapticManager.toggle() }

                    Toggle("Someone paid you", isOn: $notifySomeonePaid)
                        .onChange(of: notifySomeonePaid) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Transactions", systemImage: "creditcard.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Payment Reminders
                Section {
                    Toggle("Payment reminders", isOn: $notifyPaymentReminders)
                        .onChange(of: notifyPaymentReminders) { _, _ in HapticManager.toggle() }

                    if notifyPaymentReminders {
                        Stepper("\(reminderDaysBefore) days before due", value: $reminderDaysBefore, in: 1...14)
                    }
                } header: {
                    Label("Reminders", systemImage: "bell.badge.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Subscription Notifications
                Section {
                    Toggle("Subscription due soon", isOn: $notifySubscriptionDue)
                        .onChange(of: notifySubscriptionDue) { _, _ in HapticManager.toggle() }

                    if notifySubscriptionDue {
                        Stepper("\(subscriptionDueDays) days before billing", value: $subscriptionDueDays, in: 1...14)
                    }

                    Toggle("Subscription overdue", isOn: $notifySubscriptionOverdue)
                        .onChange(of: notifySubscriptionOverdue) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Subscriptions", systemImage: "repeat.circle.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Settlement Notifications
                Section {
                    Toggle("Settlement received", isOn: $notifySettlementReceived)
                        .onChange(of: notifySettlementReceived) { _, _ in HapticManager.toggle() }

                    Toggle("Settlement sent", isOn: $notifySettlementSent)
                        .onChange(of: notifySettlementSent) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Settlements", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Group Notifications
                Section {
                    Toggle("Added to group", isOn: $notifyAddedToGroup)
                        .onChange(of: notifyAddedToGroup) { _, _ in HapticManager.toggle() }

                    Toggle("Group expense added", isOn: $notifyGroupExpense)
                        .onChange(of: notifyGroupExpense) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Groups", systemImage: "person.3.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Chat Notifications
                Section {
                    Toggle("New messages", isOn: $notifyNewMessage)
                        .onChange(of: notifyNewMessage) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Messages", systemImage: "message.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Summary Notifications
                Section {
                    Toggle("Weekly summary", isOn: $notifyWeeklySummary)
                        .onChange(of: notifyWeeklySummary) { _, _ in HapticManager.toggle() }
                } header: {
                    Label("Summaries", systemImage: "chart.bar.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Quiet Hours
                Section {
                    Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                        .onChange(of: quietHoursEnabled) { _, _ in HapticManager.toggle() }

                    if quietHoursEnabled {
                        DatePicker("Start", selection: $quietHoursStart, displayedComponents: .hourAndMinute)

                        DatePicker("End", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Label("Quiet Hours", systemImage: "moon.fill")
                        .font(AppTypography.subheadlineMedium())
                } footer: {
                    if quietHoursEnabled {
                        Text("Notifications will be silenced during quiet hours.")
                            .font(AppTypography.caption())
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
