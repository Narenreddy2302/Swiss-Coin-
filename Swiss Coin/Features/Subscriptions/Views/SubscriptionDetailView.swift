//
//  SubscriptionDetailView.swift
//  Swiss Coin
//
//  Detail view for viewing and managing a subscription.
//  Card-based ScrollView layout with brand header, members card,
//  merged overview card, collapsible payment history, reminders,
//  and stacked action rows.
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
    @State private var paymentHistoryExpanded = true
    @State private var paymentToEdit: SubscriptionPayment?
    @State private var showingEditPayment = false
    @State private var showingDeletePaymentAlert = false
    @State private var paymentToDelete: SubscriptionPayment?

    // MARK: - Computed Properties

    private var subscriptionColor: Color {
        Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex)
    }

    private var dailyCost: Double {
        subscription.yearlyEquivalent / 365.0
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

    private var subtitleText: String {
        let cycle = subscription.cycle ?? "Monthly"
        if let category = subscription.category, !category.isEmpty {
            return "\(category) \u{00B7} \(cycle)"
        }
        return cycle
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                brandCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)

                if subscription.isShared {
                    membersCard
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.sectionGap)
                }

                overviewCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                paymentHistoryCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                notificationsCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                if let notes = subscription.notes, !notes.isEmpty {
                    notesCard(notes)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.sectionGap)
                }

                quickActions
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                metadataFooter
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xxl)
                    .padding(.bottom, Spacing.xxxl)
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
        .sheet(isPresented: $showingEditPayment) {
            if let payment = paymentToEdit {
                EditSubscriptionPaymentView(payment: payment)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .alert("Delete Payment", isPresented: $showingDeletePaymentAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let payment = paymentToDelete {
                    deletePayment(payment)
                }
            }
        } message: {
            Text("Are you sure you want to delete this payment? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Section 1: Brand Card

    private var brandCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: icon + name/subtitle
            HStack(spacing: Spacing.lg) {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(subscriptionColor.opacity(0.15))
                    .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                    .overlay(
                        Image(systemName: subscription.iconName ?? "creditcard.fill")
                            .font(.system(size: IconSize.xl))
                            .foregroundColor(subscriptionColor)
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(subscription.displayName)
                        .font(AppTypography.displayMedium())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    Text(subtitleText)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.top, Spacing.cardPadding)

            // Status pill
            StatusPill(status: subscription.billingStatus)
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.top, Spacing.md)

            // Divider
            DetailDivider()
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.top, Spacing.lg)

            // Key metrics row
            HStack(alignment: .top) {
                // Left: Amount
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Amount")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                        Text(CurrencyFormatter.format(subscription.amount))
                            .font(AppTypography.financialLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Text("/ \(subscription.cycleAbbreviation)")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Right: Next Payment
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("Next Payment")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text(subscription.nextBillingDate?.formatted(
                        .dateTime.month(.abbreviated).day().year()
                    ) ?? "Unknown")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Text(countdownText)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(countdownColor)
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.cardPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .cardShadow(for: colorScheme)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.displayName), \(CurrencyFormatter.format(subscription.amount)) per \(subscription.cycle ?? "month"), \(subscription.billingStatus.label)")
    }

    // MARK: - Section 1B: Members Card (Shared Only)

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("MEMBERS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            FlowLayout(spacing: Spacing.sm) {
                // Current user chip
                memberChip(name: "You", colorHex: nil, isCurrentUser: true)

                // Other members
                let allMembers = (subscription.subscribers as? Set<Person> ?? [])
                    .filter { !CurrentUser.isCurrentUser($0.id) }
                    .sorted { ($0.name ?? "") < ($1.name ?? "") }

                ForEach(allMembers, id: \.objectID) { member in
                    memberChip(
                        name: member.displayName,
                        colorHex: member.colorHex,
                        isCurrentUser: false
                    )
                }
            }
            .padding(Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .cardShadow(for: colorScheme)
            )
        }
    }

    private func memberChip(name: String, colorHex: String?, isCurrentUser: Bool) -> some View {
        let chipColor = isCurrentUser
            ? AppColors.accent
            : Color(hex: colorHex ?? AppColors.defaultAvatarColorHex)
        let initials = isCurrentUser
            ? "Y"
            : String(name.prefix(1)).uppercased()

        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(chipColor.opacity(0.2))
                .frame(width: IconSize.sm, height: IconSize.sm)
                .overlay(
                    Text(initials)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(chipColor)
                )

            Text(name)
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(AppColors.backgroundTertiary)
        )
    }

    // MARK: - Section 2: Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("OVERVIEW")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    DetailRow(label: "Monthly", value: CurrencyFormatter.format(subscription.monthlyEquivalent))

                    DetailDivider()

                    DetailRow(label: "Yearly", value: CurrencyFormatter.format(subscription.yearlyEquivalent))

                    DetailDivider()

                    DetailRow(label: "Daily", value: CurrencyFormatter.format(dailyCost))

                    DetailDivider()

                    DetailRow(
                        label: "Started",
                        value: subscription.startDate?.formatted(
                            .dateTime.month(.abbreviated).day().year()
                        ) ?? "Unknown"
                    )

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
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .cardShadow(for: colorScheme)
            )
        }
    }

    // MARK: - Section 3: Payment History Card

    private var paymentHistoryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(spacing: 0) {
                // Tappable header row inside card
                Button {
                    HapticManager.lightTap()
                    withAnimation(AppAnimation.standard) {
                        paymentHistoryExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: paymentHistoryExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.textTertiary)

                        Text("Payment History")
                            .font(AppTypography.headingSmall())
                            .foregroundColor(AppColors.textPrimary)

                        if !allPayments.isEmpty {
                            Text("(\(allPayments.count))")
                                .font(AppTypography.labelDefault())
                                .foregroundColor(AppColors.accent)
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
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.cardPadding)
                }
                .buttonStyle(AppButtonStyle())

                if paymentHistoryExpanded {
                    DetailDivider()
                        .padding(.horizontal, Spacing.cardPadding)

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
                            PaymentHistoryRow(
                                payment: payment,
                                onEdit: { p in
                                    paymentToEdit = p
                                    showingEditPayment = true
                                },
                                onDelete: { p in
                                    paymentToDelete = p
                                    showingDeletePaymentAlert = true
                                }
                            )

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

                    // Record Payment button inside card
                    DetailDivider()
                        .padding(.horizontal, Spacing.cardPadding)

                    Button {
                        HapticManager.tap()
                        recordPayment()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: showPaymentSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: IconSize.sm))
                            Text(showPaymentSuccess ? "Payment Recorded" : "Record Payment")
                                .font(AppTypography.labelLarge())
                        }
                        .foregroundColor(showPaymentSuccess ? AppColors.positive : AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                    }
                    .disabled(showPaymentSuccess)
                    .accessibilityLabel("Record a payment for this subscription")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .cardShadow(for: colorScheme)
            )
        }
    }

    // MARK: - Section 4: Notifications Card

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
                    .cardShadow(for: colorScheme)
            )
        }
    }

    // MARK: - Section 5: Notes Card

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
                        notesExpanded.toggle()
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
                    .cardShadow(for: colorScheme)
            )
        }
    }

    // MARK: - Section 6: Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ACTIONS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: Spacing.md) {
                // Primary: Edit
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
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Edit subscription")

                // Secondary row: Pause/Resume + Archive/Restore
                HStack(spacing: Spacing.md) {
                    Button {
                        HapticManager.tap()
                        togglePauseStatus()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: subscription.isActive ? "pause.circle" : "play.circle")
                                .font(.system(size: IconSize.sm))
                            Text(subscription.isActive ? "Pause" : "Resume")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(subscription.isActive ? "Pause subscription" : "Resume subscription")

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
                            Text(subscription.isArchived ? "Restore" : "Archive")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(subscription.isArchived ? "Restore subscription" : "Archive subscription")
                }

                // Destructive: Delete
                Button {
                    HapticManager.destructiveAction()
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "trash")
                            .font(.system(size: IconSize.sm))
                        Text("Delete Subscription")
                    }
                }
                .buttonStyle(DestructiveButtonStyle())
                .accessibilityLabel("Delete subscription")
            }
        }
    }

    // MARK: - Section 7: Metadata Footer

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
            showPaymentSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showPaymentSuccess = false
            }
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to record payment: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deletePayment(_ payment: SubscriptionPayment) {
        HapticManager.delete()
        viewContext.delete(payment)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete payment."
            showingError = true
        }
    }

    private func exportPaymentHistory() {
        // Read CoreData properties on main thread
        let csvContent = subscription.exportPaymentHistory()
        let safeName = (subscription.name ?? "Subscription")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        Task.detached(priority: .userInitiated) {
            let fileName = "\(safeName)_Payment_History.csv"
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    csvFileURL = fileURL
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    HapticManager.error()
                    errorMessage = "Failed to create export file."
                    showingError = true
                }
            }
        }
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

/// Restyled payment history row for the card layout
private struct PaymentHistoryRow: View {
    let payment: SubscriptionPayment
    var onEdit: ((SubscriptionPayment) -> Void)? = nil
    var onDelete: ((SubscriptionPayment) -> Void)? = nil

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(payment.payer?.id)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Payment icon
            Circle()
                .fill(AppColors.positive.opacity(0.12))
                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
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
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(payment.amount)
                HapticManager.copyAction()
            } label: {
                Label("Copy Amount", systemImage: "doc.on.doc")
            }

            if isUserPayer, let onEdit {
                Button {
                    HapticManager.lightTap()
                    onEdit(payment)
                } label: {
                    Label("Edit Payment", systemImage: "pencil")
                }
            }

            if isUserPayer, let onDelete {
                Divider()

                Button(role: .destructive) {
                    HapticManager.delete()
                    onDelete(payment)
                } label: {
                    Label("Delete Payment", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUserPayer ? "You" : payment.payer?.displayName ?? "Someone") paid \(CurrencyFormatter.format(payment.amount)) on \(payment.date?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "unknown date")")
        .accessibilityHint("Double tap and hold for options")
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
