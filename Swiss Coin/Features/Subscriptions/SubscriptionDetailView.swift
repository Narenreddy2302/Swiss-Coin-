//
//  SubscriptionDetailView.swift
//  Swiss Coin
//
//  Premium detail view for viewing and managing a subscription.
//  Card-based ScrollView layout with hero header, billing countdown,
//  cost summary, payment history, reminders, and quick actions.
//

import CoreData
import SwiftUI
import UIKit

// MARK: - Subscription Detail View

struct SubscriptionDetailView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // MARK: - State

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingArchiveAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var csvFileURL: URL?
    @State private var showPaymentSuccess = false
    @State private var notesExpanded = false

    // Staggered entrance animation
    @State private var sectionsAppeared = false

    // MARK: - Computed Properties

    private var subscriptionColor: Color {
        Color(hex: subscription.colorHex ?? "#007AFF")
    }

    private var dailyCost: Double {
        subscription.yearlyEquivalent / 365.0
    }

    private var totalSpent: Double {
        let paymentsSet = subscription.payments as? Set<SubscriptionPayment> ?? []
        return paymentsSet.reduce(0) { $0 + $1.amount }
    }

    private var allPayments: [SubscriptionPayment] {
        subscription.recentPayments
    }

    private var countdownText: String {
        let days = subscription.daysUntilNextBilling
        if !subscription.isActive {
            return "Paused"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 0 {
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue"
        } else {
            return "in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    private var countdownColor: Color {
        if !subscription.isActive {
            return AppColors.neutral
        }
        let days = subscription.daysUntilNextBilling
        if days < 0 {
            return AppColors.negative
        } else if days <= 7 {
            return AppColors.warning
        } else {
            return AppColors.positive
        }
    }

    private var reminderPreviewDate: Date? {
        guard subscription.notificationEnabled,
              let nextDate = subscription.nextBillingDate else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: -Int(subscription.notificationDaysBefore),
            to: nextDate
        )
    }

    private var categoryIcon: String {
        switch subscription.category?.lowercased() {
        case "entertainment": return "tv.fill"
        case "productivity": return "hammer.fill"
        case "music": return "music.note"
        case "gaming": return "gamecontroller.fill"
        case "news": return "newspaper.fill"
        case "health": return "heart.fill"
        case "education": return "graduationcap.fill"
        case "finance": return "chart.bar.fill"
        case "social": return "person.2.fill"
        case "utilities": return "wrench.fill"
        case "storage": return "externaldrive.fill"
        case "food": return "fork.knife"
        case "shopping": return "bag.fill"
        case "travel": return "airplane"
        case "fitness": return "figure.run"
        default: return "tag.fill"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeaderCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)

                billingCountdownCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval),
                        value: sectionsAppeared
                    )

                costSummaryCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 2),
                        value: sectionsAppeared
                    )

                spendingInsight
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.md)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 3),
                        value: sectionsAppeared
                    )

                paymentHistoryCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 4),
                        value: sectionsAppeared
                    )

                notificationsCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 5),
                        value: sectionsAppeared
                    )

                if let notes = subscription.notes, !notes.isEmpty {
                    notesCard(notes)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.sectionGap)
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 12)
                        .animation(
                            AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 6),
                            value: sectionsAppeared
                        )
                }

                quickActions
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .offset(y: sectionsAppeared ? 0 : 12)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 7),
                        value: sectionsAppeared
                    )

                metadataFooter
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xxl)
                    .padding(.bottom, Spacing.xxxl)
                    .opacity(sectionsAppeared ? 1 : 0)
                    .animation(
                        AppAnimation.contentReveal.delay(AppAnimation.staggerInterval * 8),
                        value: sectionsAppeared
                    )
            }
        }
        .background(AppColors.backgroundSecondary.ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundSecondary, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        HapticManager.tap()
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        HapticManager.tap()
                        if subscription.isArchived {
                            restoreSubscription()
                        } else {
                            showingArchiveAlert = true
                        }
                    } label: {
                        Label(
                            subscription.isArchived ? "Restore" : "Archive",
                            systemImage: subscription.isArchived ? "tray.and.arrow.up" : "archivebox"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        HapticManager.tap()
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSubscriptionView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = csvFileURL {
                ShareSheet(activityItems: [url])
            }
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + AppAnimation.staggerBaseDelay) {
                withAnimation(AppAnimation.contentReveal) {
                    sectionsAppeared = true
                }
            }
        }
    }

    // MARK: - Section 1: Hero Header Card

    private var heroHeaderCard: some View {
        VStack(spacing: 0) {
            // Accent color strip
            RoundedRectangle(cornerRadius: CornerRadius.full)
                .fill(subscriptionColor)
                .frame(height: 4)
                .padding(.horizontal, Spacing.xxxl)
                .padding(.top, Spacing.lg)

            // Large icon
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(subscriptionColor.opacity(0.15))
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(subscriptionColor)
                )
                .padding(.top, Spacing.xxl)

            // Subscription name
            Text(subscription.displayName)
                .font(AppTypography.displayLarge())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.md)

            // Amount with cycle
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.format(subscription.amount))
                    .font(AppTypography.financialHero())
                    .foregroundColor(AppColors.textPrimary)

                Text("/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, Spacing.sm)

            // Status pill
            StatusPill(status: subscription.billingStatus)
                .padding(.top, Spacing.md)

            // Category tag
            if let category = subscription.category, !category.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: IconSize.xs))
                    Text(category)
                        .font(AppTypography.labelDefault())
                }
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
                .padding(.top, Spacing.sm)
            }
        }
        .padding(.bottom, Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.displayName), \(CurrencyFormatter.format(subscription.amount)) per \(subscription.cycle ?? "month"), \(subscription.billingStatus.label)")
    }

    // MARK: - Section 2: Billing Countdown Card

    private var billingCountdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("BILLING")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                // Next Payment row with countdown
                HStack {
                    Text("Next Payment")
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text(subscription.nextBillingDate?.formatted(
                            .dateTime.month(.abbreviated).day().year()
                        ) ?? "Unknown")
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Text(countdownText)
                            .font(AppTypography.labelDefault())
                            .foregroundColor(countdownColor)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                Capsule()
                                    .fill(countdownColor.opacity(0.12))
                            )
                    }
                }
                .padding(.vertical, Spacing.md)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next payment \(subscription.nextBillingDate?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "unknown"), \(countdownText)")

                DetailDivider()

                // Billing Cycle row
                DetailRow(label: "Billing Cycle", value: subscription.cycle ?? "Monthly")

                DetailDivider()

                // Start Date row
                DetailRow(
                    label: "Started",
                    value: subscription.startDate?.formatted(
                        .dateTime.month(.abbreviated).day().year()
                    ) ?? "Unknown"
                )

                // Category row
                if let category = subscription.category, !category.isEmpty {
                    DetailDivider()

                    HStack {
                        Text("Category")
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        HStack(spacing: Spacing.xs) {
                            Image(systemName: categoryIcon)
                                .font(.system(size: IconSize.xs))
                                .foregroundColor(AppColors.textSecondary)
                            Text(category)
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    // MARK: - Section 3: Cost Summary Card

    private var costSummaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("COST SUMMARY")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.lg) {
                // Three cost blocks horizontally
                HStack(spacing: 0) {
                    CostBlock(
                        icon: "calendar",
                        label: "Monthly",
                        amount: CurrencyFormatter.format(subscription.monthlyEquivalent)
                    )

                    // Vertical divider
                    Rectangle()
                        .fill(AppColors.divider)
                        .frame(width: 0.5)
                        .padding(.vertical, Spacing.xs)

                    CostBlock(
                        icon: "calendar.badge.clock",
                        label: "Yearly",
                        amount: CurrencyFormatter.format(subscription.yearlyEquivalent)
                    )

                    // Vertical divider
                    Rectangle()
                        .fill(AppColors.divider)
                        .frame(width: 0.5)
                        .padding(.vertical, Spacing.xs)

                    CostBlock(
                        icon: "sun.max",
                        label: "Daily",
                        amount: CurrencyFormatter.format(dailyCost)
                    )
                }

                // Yearly projection
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: IconSize.xs))
                        .foregroundColor(AppColors.textTertiary)

                    (Text("Yearly projection: ")
                        + Text(CurrencyFormatter.format(subscription.yearlyEquivalent)).fontWeight(.bold))
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    // MARK: - Spending Insight

    private var spendingInsight: some View {
        Group {
            if totalSpent > 0 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.info)

                    (Text("You've spent ")
                        + Text(CurrencyFormatter.format(totalSpent)).fontWeight(.bold)
                        + Text(" on \(subscription.displayName)")
                        + Text(subscription.startDate != nil
                            ? " since \(subscription.startDate!.formatted(.dateTime.month(.abbreviated).year()))"
                            : ""))
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.infoMuted)
                )
            }
        }
    }

    // MARK: - Section 4: Payment History Card

    private var paymentHistoryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header with count badge and export button
            HStack {
                Text("PAYMENT HISTORY")
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textTertiary)

                if !allPayments.isEmpty {
                    Text("\(allPayments.count)")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(AppColors.backgroundTertiary)
                        )
                }

                Spacer()

                if !allPayments.isEmpty {
                    Button {
                        HapticManager.tap()
                        exportPaymentHistory()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Export payment history")
                }
            }

            VStack(spacing: 0) {
                if allPayments.isEmpty {
                    // Empty state
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: IconSize.xl))
                            .foregroundColor(AppColors.textTertiary)

                        Text("No payments recorded")
                            .font(AppTypography.headingSmall())
                            .foregroundColor(AppColors.textSecondary)

                        Text("Payments will appear here after you mark this subscription as paid")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
                } else {
                    let displayPayments = Array(allPayments.prefix(5))
                    ForEach(Array(displayPayments.enumerated()), id: \.element.objectID) { index, payment in
                        PaymentHistoryRow(payment: payment)

                        if index < displayPayments.count - 1 {
                            DetailDivider()
                                .padding(.horizontal, Spacing.cardPadding)
                        }
                    }

                    if allPayments.count > 5 {
                        DetailDivider()
                            .padding(.horizontal, Spacing.cardPadding)

                        Button {
                            HapticManager.tap()
                        } label: {
                            Text("View All \(allPayments.count) Payments")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )

            // Record Payment button
            Button {
                HapticManager.tap()
                recordPayment()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: showPaymentSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: IconSize.sm))
                    Text(showPaymentSuccess ? "Payment Recorded" : "Record Payment")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(showPaymentSuccess)
            .accessibilityLabel("Record a payment for this subscription")
        }
    }

    // MARK: - Section 5: Notifications Card

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("REMINDERS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                // Toggle row
                HStack(spacing: Spacing.md) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(subscription.notificationEnabled ? AppColors.accent : AppColors.textTertiary)

                    Text("Payment Reminders")
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { subscription.notificationEnabled },
                        set: { newValue in
                            subscription.notificationEnabled = newValue
                            do {
                                try viewContext.save()
                                HapticManager.toggle()
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
                    .labelsHidden()
                    .tint(AppColors.accent)
                }
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.cardPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Payment Reminders, \(subscription.notificationEnabled ? "enabled" : "disabled")")

                if subscription.notificationEnabled {
                    DetailDivider()
                        .padding(.horizontal, Spacing.cardPadding)

                    // Stepper row
                    Stepper(
                        value: Binding(
                            get: { Int(subscription.notificationDaysBefore) },
                            set: { newValue in
                                subscription.notificationDaysBefore = Int16(newValue)
                                do {
                                    try viewContext.save()
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
                    ) {
                        HStack(spacing: Spacing.xs) {
                            Text("Remind")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)
                            Text("\(subscription.notificationDaysBefore) day\(subscription.notificationDaysBefore == 1 ? "" : "s")")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.accent)
                            Text("before")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.cardPadding)

                    // Reminder preview
                    if let reminderDate = reminderPreviewDate {
                        DetailDivider()
                            .padding(.horizontal, Spacing.cardPadding)

                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.info)

                            Text("You'll be reminded on \(reminderDate.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.info)
                        }
                        .padding(.vertical, Spacing.md)
                        .padding(.horizontal, Spacing.cardPadding)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    // MARK: - Section 6: Notes Card

    @ViewBuilder
    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("NOTES")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                Text(notes)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(notesExpanded ? nil : 3)
                    .padding(Spacing.cardPadding)

                if notes.count > 120 {
                    DetailDivider()
                        .padding(.horizontal, Spacing.cardPadding)

                    Button {
                        HapticManager.lightTap()
                        withAnimation(AppAnimation.standard) {
                            notesExpanded.toggle()
                        }
                    } label: {
                        Text(notesExpanded ? "Show Less" : "Show More")
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    // MARK: - Section 7: Quick Actions

    private var quickActions: some View {
        VStack(spacing: Spacing.md) {
            // Edit
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.sm))
                    Text("Edit Subscription")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Edit subscription details")

            // Pause / Resume
            Button {
                HapticManager.tap()
                togglePauseStatus()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: subscription.isActive ? "pause.circle" : "play.circle")
                        .font(.system(size: IconSize.sm))
                    Text(subscription.isActive ? "Pause Subscription" : "Resume Subscription")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(subscription.isActive ? "Pause this subscription" : "Resume this subscription")

            // Archive / Restore
            Button {
                HapticManager.tap()
                if subscription.isArchived {
                    restoreSubscription()
                } else {
                    showingArchiveAlert = true
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: subscription.isArchived ? "tray.and.arrow.up" : "archivebox")
                        .font(.system(size: IconSize.sm))
                    Text(subscription.isArchived ? "Restore Subscription" : "Archive Subscription")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(subscription.isArchived ? "Restore this subscription" : "Archive this subscription")

            Spacer()
                .frame(height: Spacing.sm)

            // Cancel / Delete
            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.sm))
                    Text("Cancel Subscription")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .accessibilityLabel("Cancel and delete this subscription")
        }
    }

    // MARK: - Section 8: Metadata Footer

    private var metadataFooter: some View {
        VStack(spacing: Spacing.xs) {
            if let startDate = subscription.startDate {
                Text("Created \(startDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            let id = subscription.objectID.uriRepresentation().lastPathComponent
            if !id.isEmpty {
                Text("ID: \(id)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Business Logic

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
            errorMessage = "Failed to update subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func archiveSubscription() {
        subscription.isArchived = true
        subscription.isActive = false
        do {
            try viewContext.save()
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
        subscription.isActive = true
        do {
            try viewContext.save()
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

    private func recordPayment() {
        let payment = SubscriptionPayment(context: viewContext)
        payment.id = UUID()
        payment.amount = subscription.amount
        payment.date = Date()
        payment.subscription = subscription
        payment.payer = CurrentUser.getOrCreate(in: viewContext)

        // Advance next billing date
        subscription.nextBillingDate = subscription.calculateNextBillingDate(from: Date())

        do {
            try viewContext.save()

            // Reschedule notification for the new billing date
            if subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }

            HapticManager.success()

            // Show brief success state
            withAnimation(AppAnimation.fast) {
                showPaymentSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(AppAnimation.fast) {
                    showPaymentSuccess = false
                }
            }
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to record payment: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func exportPaymentHistory() {
        guard let url = subscription.createPaymentHistoryCSVFile() else {
            HapticManager.error()
            errorMessage = "Failed to create export file."
            showingError = true
            return
        }
        csvFileURL = url
        showingShareSheet = true
    }
}

// MARK: - Supporting Views

/// A single row showing a label-value pair in the detail card
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Hairline divider for card internals
private struct DetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 0.5)
    }
}

/// A single cost metric block (used in the cost summary HStack)
private struct CostBlock: View {
    let icon: String
    let label: String
    let amount: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.textTertiary)

            Text(label)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            Text(amount)
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(amount)")
    }
}

/// Restyled payment history row for the card layout
private struct PaymentHistoryRow: View {
    let payment: SubscriptionPayment

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Payment icon
            Circle()
                .fill(AppColors.positive.opacity(0.12))
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.positive)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(isUserPayer ? "You paid" : "\(payment.payer?.displayName ?? "Someone") paid")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(payment.date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Text(CurrencyFormatter.format(payment.amount))
                .font(AppTypography.financialSmall())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.cardPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUserPayer ? "You" : payment.payer?.displayName ?? "Someone") paid \(CurrencyFormatter.format(payment.amount)) on \(payment.date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "unknown date")")
    }
}

/// Share sheet wrapper for UIActivityViewController
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
