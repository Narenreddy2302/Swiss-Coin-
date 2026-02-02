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
    @State private var isPressed = false
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

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Subscription Icon (like Person avatar)
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(AppTypography.headline())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                )
                .accessibilityHidden(true)

            // Name and Status
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Text(subscription.cycle ?? "Monthly")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(statusText)
                        .font(AppTypography.subheadline())
                        .foregroundColor(billingStatus.color)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.format(subscription.amount))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(AppColors.textPrimary)

                Text("/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                HapticManager.tap()
                markAsPaid()
            } label: {
                Label("Mark as Paid", systemImage: "checkmark.circle")
            }

            Button {
                HapticManager.tap()
                togglePauseStatus()
            } label: {
                Label(
                    subscription.isActive ? "Pause" : "Resume",
                    systemImage: subscription.isActive ? "pause.circle" : "play.circle"
                )
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.tap()
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
