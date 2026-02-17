//
//  UnifiedSubscriptionRowView.swift
//  Swiss Coin
//
//  Unified row component for both personal and shared subscriptions.
//  Replaces SubscriptionListRowView and SharedSubscriptionListRowView.
//

import CoreData
import os
import SwiftUI

// MARK: - Balance Display Info

struct BalanceDisplayInfo {
    let amount: Double
    let text: String
    let color: Color

    init(balance: Double) {
        self.amount = balance
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            self.text = "you're owed \(formatted)"
            self.color = AppColors.positive
        } else if balance < -0.01 {
            self.text = "you owe \(formatted)"
            self.color = AppColors.negative
        } else {
            self.text = "settled up"
            self.color = AppColors.neutral
        }
    }
}

// MARK: - UnifiedSubscriptionRowView

struct UnifiedSubscriptionRowView: View {
    @ObservedObject var subscription: Subscription
    let isShared: Bool
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingRecordPayment = false
    @State private var showingReminder = false
    @State private var showingDetail = false
    @State private var cachedBillingStatus: BillingStatus = .upcoming
    @State private var cachedBalanceInfo: BalanceDisplayInfo = BalanceDisplayInfo(balance: 0)

    private var billingStatus: BillingStatus { cachedBillingStatus }

    private var statusText: String {
        switch billingStatus {
        case .overdue:
            return "Overdue"
        case .due:
            let days = subscription.daysUntilNextBilling
            if days == 0 {
                return "Due today"
            } else if days == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(days)d"
            }
        case .upcoming:
            return "Active"
        case .paused:
            return "Paused"
        }
    }

    private var balanceInfo: BalanceDisplayInfo { cachedBalanceInfo }

    private var memberCount: Int {
        subscription.memberCount
    }

    private var accessibilityDescription: String {
        let name = subscription.name ?? "Unknown"
        let amount = CurrencyFormatter.format(subscription.amount)
        let cycle = subscription.cycle ?? "Monthly"
        if isShared {
            return "\(name), \(amount) per \(cycle), \(memberCount + 1) members, \(balanceInfo.text)"
        }
        return "\(name), \(amount) per \(cycle), \(statusText)"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Subscription Icon
            subscriptionIcon

            // Name and Status
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                // Line 2: Cycle + Status
                HStack(spacing: Spacing.xs) {
                    Text(subscription.cycle ?? "Monthly")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text("\u{2022}")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text(statusText)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(billingStatus.color)
                }
                .lineLimit(1)

                // Line 3: Shared balance info
                if isShared {
                    Text(balanceInfo.text)
                        .font(AppTypography.labelSmall())
                        .foregroundColor(balanceInfo.color)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.format(subscription.amount))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)

                Text("/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            cachedBillingStatus = subscription.billingStatus
            if isShared {
                cachedBalanceInfo = BalanceDisplayInfo(balance: subscription.calculateUserBalance())
            }
        }
        .onChange(of: subscription.nextBillingDate) { _, _ in
            cachedBillingStatus = subscription.billingStatus
        }
        .onChange(of: subscription.isActive) { _, _ in
            cachedBillingStatus = subscription.billingStatus
        }
        .onChange(of: subscription.payments?.count) { _, _ in
            if isShared {
                cachedBalanceInfo = BalanceDisplayInfo(balance: subscription.calculateUserBalance())
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isShared {
                Button {
                    HapticManager.tap()
                    showingRecordPayment = true
                } label: {
                    Label("Pay", systemImage: "dollarsign.circle")
                }
                .tint(AppColors.accent)
            } else {
                Button {
                    HapticManager.tap()
                    markAsPaid()
                } label: {
                    Label("Paid", systemImage: "checkmark.circle")
                }
                .tint(AppColors.accent)
            }

            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppColors.info)
        }
        .contextMenu {
            if isShared {
                sharedContextMenu
            } else {
                personalContextMenu
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSubscriptionView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Subscription", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSubscription()
            }
        } message: {
            Text("Are you sure you want to delete \"\(subscription.name ?? "this subscription")\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                SubscriptionDetailView(subscription: subscription)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDetail = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecordPayment) {
            RecordSubscriptionPaymentView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingReminder) {
            SubscriptionReminderSheetView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Icon

    private var subscriptionIcon: some View {
        RoundedRectangle(cornerRadius: CornerRadius.sm)
            .fill(Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.2))
            .frame(width: AvatarSize.lg, height: AvatarSize.lg)
            .overlay(
                Image(systemName: subscription.iconName ?? (isShared ? "person.2.circle.fill" : "creditcard.fill"))
                    .font(AppTypography.headingMedium())
                    .foregroundColor(Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex))
            )
            .accessibilityHidden(true)
    }

    // MARK: - Context Menus

    @ViewBuilder
    private var personalContextMenu: some View {
        Button {
            HapticManager.lightTap()
            showingEditSheet = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            HapticManager.lightTap()
            markAsPaid()
        } label: {
            Label("Mark as Paid", systemImage: "checkmark.circle")
        }

        Button {
            HapticManager.lightTap()
            togglePauseStatus()
        } label: {
            Label(
                subscription.isActive ? "Pause" : "Resume",
                systemImage: subscription.isActive ? "pause.circle" : "play.circle"
            )
        }

        Divider()

        Button(role: .destructive) {
            HapticManager.delete()
            showingDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var sharedContextMenu: some View {
        Button {
            HapticManager.lightTap()
            showingDetail = true
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Button {
            HapticManager.lightTap()
            showingRecordPayment = true
        } label: {
            Label("Record Payment", systemImage: "dollarsign.circle")
        }

        Button {
            HapticManager.lightTap()
            showingReminder = true
        } label: {
            Label("Send Reminders", systemImage: "bell")
        }

        Divider()

        Button {
            HapticManager.lightTap()
            showingEditSheet = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            HapticManager.lightTap()
            togglePauseStatus()
        } label: {
            Label(
                subscription.isActive ? "Pause" : "Resume",
                systemImage: subscription.isActive ? "pause.circle" : "play.circle"
            )
        }

        Divider()

        Button(role: .destructive) {
            HapticManager.delete()
            showingDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func togglePauseStatus() {
        subscription.isActive.toggle()
        do {
            try viewContext.save()
            if subscription.isActive && subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            } else {
                NotificationManager.shared.cancelSubscriptionReminder(for: subscription)
            }
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.subscriptions.error("Failed to toggle subscription status: \(error.localizedDescription)")
        }
    }

    private func markAsPaid() {
        let billingPeriodStart = subscription.nextBillingDate ?? Date()
        let newNextBillingDate = subscription.calculateNextBillingDate(from: Date())
        subscription.nextBillingDate = newNextBillingDate

        let payment = SubscriptionPayment(context: viewContext)
        payment.id = UUID()
        payment.amount = subscription.amount
        payment.date = Date()
        payment.billingPeriodStart = billingPeriodStart
        payment.billingPeriodEnd = newNextBillingDate
        payment.payer = CurrentUser.getOrCreate(in: viewContext)
        payment.subscription = subscription

        do {
            try viewContext.save()
            if subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.subscriptions.error("Failed to mark subscription as paid: \(error.localizedDescription)")
        }
    }

    private func deleteSubscription() {
        HapticManager.delete()
        NotificationManager.shared.cancelSubscriptionReminder(for: subscription)
        viewContext.delete(subscription)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.subscriptions.error("Failed to delete subscription: \(error.localizedDescription)")
        }
    }
}
