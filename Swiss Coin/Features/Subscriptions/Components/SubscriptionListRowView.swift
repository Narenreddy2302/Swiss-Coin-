//
//  SubscriptionListRowView.swift
//  Swiss Coin
//
//  List row for personal subscriptions, matching PersonListRowView pattern.
//

import CoreData
import os
import SwiftUI

struct SubscriptionListRowView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var billingStatus: BillingStatus {
        subscription.billingStatus
    }

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
                return "Due in \(days) days"
            }
        case .upcoming:
            if let date = subscription.nextBillingDate {
                return "Next: \(date.formatted(.dateTime.month(.abbreviated).day()))"
            }
            return "Upcoming"
        case .paused:
            return "Paused"
        }
    }

    private var accessibilityDescription: String {
        let name = subscription.name ?? "Unknown"
        let amount = CurrencyFormatter.format(subscription.amount)
        let cycle = subscription.cycle ?? "Monthly"
        return "\(name), \(amount) per \(cycle), \(statusText)"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Subscription Icon (like Person avatar)
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                )
                .accessibilityHidden(true)

            // Name and Status
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

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
        .contextMenu {
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
            AppLogger.subscriptions.error("Failed to toggle subscription status: \(error.localizedDescription)")
        }
    }

    private func markAsPaid() {
        // Capture current billing date before advancing
        let billingPeriodStart = subscription.nextBillingDate ?? Date()

        // Advance next billing date
        let newNextBillingDate = subscription.calculateNextBillingDate(from: Date())
        subscription.nextBillingDate = newNextBillingDate

        // Create a payment record for this billing cycle
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

            // Reschedule notification for the new billing date
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

        // Cancel any pending notification before deleting
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
