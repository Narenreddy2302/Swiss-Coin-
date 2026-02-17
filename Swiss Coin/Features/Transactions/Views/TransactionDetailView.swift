//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Premium card-based transaction detail page matching SubscriptionDetailView.
//  Hero header, card sections with proper shadows.
//

import CoreData
import os
import SwiftUI

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var notesExpanded = false

    private var snapshot: TransactionSnapshot {
        TransactionSnapshot.build(from: transaction)
    }

    var body: some View {
        Group {
            if transaction.isDeleted || transaction.managedObjectContext == nil {
                deletedPlaceholder
            } else {
                mainContent
            }
        }
    }

    // MARK: - Deleted Placeholder

    private var deletedPlaceholder: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textTertiary)
            Text("Transaction no longer available")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Section 1: Hero Header
                heroHeaderCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)

                // Section 2: Transaction Info
                transactionInfoCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                // Section 3: Participants
                participantsCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                // Section 4: Paid By Amounts (multi-payer only)
                if snapshot.isMultiPayer && snapshot.sortedPayers.count > 1 {
                    paidByAmountsCard
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.sectionGap)
                }

                // Section 5: Net Position
                netPositionCard
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                // Section 6: Notes (conditional)
                if let cleanNote = snapshot.cleanNote {
                    notesCard(cleanNote)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.sectionGap)
                }

                // Section 7: Quick Actions
                quickActions
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.sectionGap)

                // Section 8: Metadata Footer
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
                        showEditSheet = true
                    } label: {
                        Label("Edit Transaction", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Transaction", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not delete this transaction. Please try again.")
        }
    }

    // MARK: - Section 1: Hero Header Card

    private var heroHeaderCard: some View {
        let heroColor = snapshot.categoryColor ?? AppColors.accent

        return VStack(spacing: 0) {
            // Large icon
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(heroColor.opacity(0.15))
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Group {
                        if let emoji = snapshot.categoryIcon {
                            Text(emoji)
                                .font(.system(size: IconSize.xl))
                        } else {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.system(size: IconSize.xl))
                                .foregroundColor(heroColor)
                        }
                    }
                )
                .padding(.top, Spacing.xxxl)

            // Transaction title
            Text(snapshot.title)
                .font(AppTypography.displayLarge())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

            // Date
            Text(snapshot.formattedDate)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, Spacing.xs)

            // Amount
            Text(FinancialFormatter.currency(snapshot.totalAmount, currencyCode: snapshot.currencyCode))
                .font(AppTypography.financialHero())
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, Spacing.sm)

            // Status + Split method pills
            HStack(spacing: Spacing.sm) {
                // Status pill
                HStack(spacing: Spacing.xs) {
                    Image(systemName: snapshot.directionIcon)
                        .font(.system(size: IconSize.xs))
                    Text(snapshot.statusText)
                        .font(AppTypography.labelDefault())
                }
                .foregroundColor(snapshot.netAmountColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(snapshot.netAmountColor.opacity(0.15))
                )

                // Split method pill
                HStack(spacing: Spacing.xs) {
                    Text(snapshot.splitMethodIcon)
                        .font(AppTypography.labelDefault())
                    Text(snapshot.splitMethodName)
                        .font(AppTypography.labelDefault())
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
            }
            .padding(.top, Spacing.md)

            // Category tag (conditional)
            if let categoryName = snapshot.categoryName, let categoryIcon = snapshot.categoryIcon {
                HStack(spacing: Spacing.xs) {
                    Text(categoryIcon)
                        .font(AppTypography.labelDefault())
                    Text(categoryName)
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

            // Group tag (conditional)
            if let groupName = snapshot.groupName {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: IconSize.xs))
                    Text(groupName)
                        .font(AppTypography.labelDefault())
                }
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
                .padding(.top, Spacing.xs)
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
        .accessibilityLabel("\(snapshot.title), \(FinancialFormatter.currency(snapshot.totalAmount, currencyCode: snapshot.currencyCode)), \(snapshot.statusText)")
    }

    // MARK: - Section 2: Transaction Info Card

    private var transactionInfoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DETAILS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                // Paid by
                infoRow(label: "Paid by", value: snapshot.payerName)

                CardDivider()
                    .padding(.horizontal, Spacing.cardPadding)

                // Participants
                infoRow(label: "Participants", value: "\(snapshot.participantCount) \(snapshot.participantCount == 1 ? "person" : "people")")

                CardDivider()
                    .padding(.horizontal, Spacing.cardPadding)

                // Split method
                infoRow(label: "Split method", value: "\(snapshot.splitMethodIcon) \(snapshot.splitMethodName)")

                CardDivider()
                    .padding(.horizontal, Spacing.cardPadding)

                // Currency
                let currency = Currency.fromCode(snapshot.currencyCode)
                infoRow(label: "Currency", value: "\(currency.symbol) \(currency.code)")

                CardDivider()
                    .padding(.horizontal, Spacing.cardPadding)

                // Created by
                infoRow(label: "Created by", value: snapshot.creatorName)
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

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.cardPadding)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section 3: Participants Card

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT DETAILS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                let participants = snapshot.unifiedParticipants
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    UnifiedParticipantRow(participant: participant)
                        .padding(.horizontal, Spacing.cardPadding)

                    if index < participants.count - 1 {
                        CardDivider()
                            .padding(.horizontal, Spacing.cardPadding)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
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

    // MARK: - Section 4: Paid By Amounts Card (multi-payer)

    private var paidByAmountsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PAID BY")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                ForEach(Array(snapshot.sortedPayers.enumerated()), id: \.offset) { index, payer in
                    HStack {
                        Text(payer.name)
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text(FinancialFormatter.currency(payer.amount, currencyCode: snapshot.currencyCode))
                            .font(AppTypography.financialSmall())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.cardPadding)

                    if index < snapshot.sortedPayers.count - 1 {
                        CardDivider()
                            .padding(.horizontal, Spacing.cardPadding)
                    }
                }

                CardDivider()
                    .padding(.horizontal, Spacing.cardPadding)

                // Total row
                HStack {
                    Text("Total")
                        .font(AppTypography.headingSmall())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(FinancialFormatter.currency(snapshot.totalAmount, currencyCode: snapshot.currencyCode))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.cardPadding)
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

    // MARK: - Section 5: Net Position Card

    private var netPositionCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: snapshot.directionIcon)
                .font(.system(size: IconSize.md, weight: .medium))
                .foregroundColor(snapshot.netAmountColor)

            Text(snapshot.statusText)
                .font(AppTypography.headingMedium())
                .foregroundColor(snapshot.netAmountColor)

            Spacer()

            Text(FinancialFormatter.signedCurrency(snapshot.userNetAmount, currencyCode: snapshot.currencyCode))
                .font(AppTypography.financialDefault())
                .foregroundColor(snapshot.netAmountColor)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(netPositionBackground)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net position: \(snapshot.statusText) \(FinancialFormatter.signedCurrency(snapshot.userNetAmount, currencyCode: snapshot.currencyCode))")
    }

    private var netPositionBackground: Color {
        if snapshot.userNetAmount > 0.01 { return AppColors.positiveMuted }
        if snapshot.userNetAmount < -0.01 { return AppColors.negativeMuted }
        return AppColors.neutralMuted
    }

    // MARK: - Section 6: Notes Card

    private func notesCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("NOTES")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                Text(note)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(notesExpanded ? nil : 3)
                    .padding(Spacing.cardPadding)

                if note.count > 120 {
                    CardDivider()
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
            Button {
                HapticManager.tap()
                showEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.sm))
                    Text("Edit Transaction")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Edit transaction")

            Button {
                HapticManager.destructiveAction()
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.sm))
                    Text("Delete Transaction")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .accessibilityLabel("Delete transaction")
        }
    }

    // MARK: - Section 8: Metadata Footer

    private var metadataFooter: some View {
        VStack(spacing: Spacing.xs) {
            if let date = transaction.date {
                Text("Created \(DateFormatter.longDate.string(from: date)) at \(DateFormatter.timeOnly.string(from: date))")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            let id = transaction.objectID.uriRepresentation().lastPathComponent
            if !id.isEmpty {
                Text("ID: \(id)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic Functions

    private func deleteTransaction() {
        // Delete associated splits first
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }
        // Delete associated payers
        if let payers = transaction.payers as? Set<TransactionPayer> {
            payers.forEach { viewContext.delete($0) }
        }
        // Delete associated comments
        if let comments = transaction.comments as? Set<ChatMessage> {
            comments.forEach { viewContext.delete($0) }
        }
        // Delete the transaction itself
        viewContext.delete(transaction)

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            showDeleteError = true
            AppLogger.transactions.error("Failed to delete transaction: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting View Components

/// Unified participant row for the split details card
struct UnifiedParticipantRow: View {
    let participant: TransactionSnapshot.UnifiedParticipant

    var body: some View {
        HStack(spacing: Spacing.md) {
            ConversationAvatarView(
                initials: participant.initials,
                colorHex: participant.colorHex,
                size: AvatarSize.sm
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(participant.name)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(participant.subtitle)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(FinancialFormatter.currency(participant.displayAmount, currencyCode: participant.currencyCode))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.textPrimary)

                if participant.isPaid {
                    HStack(spacing: Spacing.xxs) {
                        Text("Paid")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.positive)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.positive)
                    }
                } else {
                    Text(participant.statusText)
                        .font(AppTypography.caption())
                        .foregroundColor(participant.statusColor)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

/// Card divider
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider.opacity(0.6))
            .frame(height: 0.5)
    }
}

// MARK: - Transaction Snapshot

/// Immutable snapshot of transaction data for view rendering
struct TransactionSnapshot {
    var title: String = "Unknown"
    var currencyCode: String = CurrencyFormatter.currencyCode
    var totalAmount: Double = 0
    var userNetAmount: Double = 0
    var formattedDate: String = ""
    var formattedTime: String = ""
    var payerName: String = ""
    var creatorName: String = ""
    var participantCount: Int = 1
    var splitMethodName: String = "Equally"
    var splitMethodIcon: String = ""
    var groupName: String? = nil
    var note: String? = nil
    var isMultiPayer: Bool = false
    var sortedPayers: [(name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []
    var sortedSplits: [(objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []

    // Category fields
    var categoryId: String? = nil
    var categoryName: String? = nil
    var categoryIcon: String? = nil
    var categoryColor: Color? = nil
    var cleanNote: String? = nil

    var netAmountColor: Color {
        if userNetAmount > 0.01 { return AppColors.positive }
        if userNetAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    var directionIcon: String {
        userNetAmount > 0.01 ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill"
    }

    var statusText: String {
        if userNetAmount > 0.01 { return "You are owed" }
        if userNetAmount < -0.01 { return "You owe" }
        return "Settled"
    }

    var paymentSummaryText: String {
        if userNetAmount < -0.01 {
            let nonUserPayers = sortedPayers.filter { !$0.isUser }
            if nonUserPayers.count == 1 {
                return "You paid \(nonUserPayers[0].name)"
            }
            return "You owe"
        } else if userNetAmount > 0.01 {
            let nonUserSplits = sortedSplits.filter { !$0.isUser }
            if nonUserSplits.count == 1 {
                return "\(nonUserSplits[0].name) owes you"
            }
            return "You are owed"
        }
        return "Settled up"
    }

    // MARK: - Unified Participant

    struct UnifiedParticipant: Identifiable {
        let id: String
        let name: String
        let initials: String
        let colorHex: String
        let displayAmount: Double
        let currencyCode: String
        let subtitle: String
        let statusText: String
        let statusColor: Color
        let isPaid: Bool
        let isUser: Bool
    }

    var unifiedParticipants: [UnifiedParticipant] {
        var result: [UnifiedParticipant] = []
        let primaryPayerName = sortedPayers.first?.name ?? "payer"
        var addedNames = Set<String>()

        for (index, payer) in sortedPayers.enumerated() {
            let splitAmount = sortedSplits.first(where: { $0.name == payer.name })?.amount ?? 0
            result.append(UnifiedParticipant(
                id: "payer-\(index)",
                name: payer.name,
                initials: payer.initials,
                colorHex: payer.colorHex,
                displayAmount: splitAmount > 0 ? splitAmount : payer.amount,
                currencyCode: currencyCode,
                subtitle: "Paid \(FinancialFormatter.currency(payer.amount, currencyCode: currencyCode))",
                statusText: "Your share",
                statusColor: AppColors.textTertiary,
                isPaid: false,
                isUser: payer.isUser
            ))
            addedNames.insert(payer.name)
        }

        for (index, split) in sortedSplits.enumerated() {
            if addedNames.contains(split.name) { continue }

            result.append(UnifiedParticipant(
                id: "split-\(index)",
                name: split.name,
                initials: split.initials,
                colorHex: split.colorHex,
                displayAmount: split.amount,
                currencyCode: currencyCode,
                subtitle: "Owes \(primaryPayerName)",
                statusText: "Pending",
                statusColor: AppColors.warning,
                isPaid: false,
                isUser: split.isUser
            ))
        }

        return result
    }

    static func build(from tx: FinancialTransaction) -> TransactionSnapshot {
        var s = TransactionSnapshot()
        s.title = tx.title ?? "Unknown Transaction"
        s.currencyCode = tx.effectiveCurrency
        s.totalAmount = tx.amount

        if let date = tx.date {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                s.formattedDate = "Today, \(DateFormatter.timeOnly.string(from: date))"
            } else if calendar.isDateInYesterday(date) {
                s.formattedDate = "Yesterday, \(DateFormatter.timeOnly.string(from: date))"
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
                let dayOfWeek = DateFormatter.dayOfWeek.string(from: date)
                s.formattedDate = "\(dayOfWeek), \(DateFormatter.timeOnly.string(from: date))"
            } else {
                s.formattedDate = DateFormatter.mediumDate.string(from: date)
            }
            s.formattedTime = DateFormatter.timeOnly.string(from: date)
        } else {
            s.formattedDate = "Unknown date"
            s.formattedTime = ""
        }

        let effectivePayers = tx.effectivePayers
        s.isMultiPayer = tx.isMultiPayer

        if tx.isMultiPayer, let payerSet = tx.payers as? Set<TransactionPayer> {
            s.sortedPayers = payerSet
                .sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                .map { tp in
                    let isUser = CurrentUser.isCurrentUser(tp.paidBy?.id)
                    return (name: isUser ? "You" : (tp.paidBy?.displayName ?? "Unknown"),
                            initials: isUser ? "ME" : (tp.paidBy?.initials ?? "?"),
                            colorHex: isUser ? AppColors.defaultAvatarColorHex : (tp.paidBy?.colorHex ?? AppColors.defaultAvatarColorHex),
                            amount: tp.amount,
                            isUser: isUser)
                }
        } else if let payer = tx.payer {
            let isUser = CurrentUser.isCurrentUser(payer.id)
            s.sortedPayers = [(name: isUser ? "You" : payer.displayName,
                              initials: isUser ? "ME" : payer.initials,
                              colorHex: isUser ? AppColors.defaultAvatarColorHex : (payer.colorHex ?? AppColors.defaultAvatarColorHex),
                              amount: tx.amount,
                              isUser: isUser)]
        }

        s.payerName = TransactionDetailHelpers.payerName(effectivePayers: effectivePayers, payer: tx.payer)
        s.creatorName = TransactionDetailHelpers.creatorName(transaction: tx)

        let splitSet = tx.splits as? Set<TransactionSplit> ?? []
        let sorted = splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
        s.sortedSplits = sorted.map { split in
            let person = split.owedBy
            let isUser = CurrentUser.isCurrentUser(person?.id)
            return (objectID: split.objectID,
                    name: isUser ? "You" : (person?.displayName ?? "Unknown"),
                    initials: isUser ? "ME" : (person?.initials ?? "?"),
                    colorHex: isUser ? AppColors.defaultAvatarColorHex : (person?.colorHex ?? AppColors.defaultAvatarColorHex),
                    amount: split.amount,
                    isUser: isUser)
        }

        s.participantCount = TransactionDetailHelpers.participantCount(effectivePayers: effectivePayers, splits: sorted)
        s.userNetAmount = TransactionDetailHelpers.userNetAmount(effectivePayers: effectivePayers, splits: sorted)

        if let raw = tx.splitMethod, let method = SplitMethod(rawValue: raw) {
            s.splitMethodName = method.displayName
            s.splitMethodIcon = method.icon
        }

        s.groupName = tx.group?.name

        // Category-aware note parsing
        let rawNote = tx.note ?? ""
        if rawNote.hasPrefix("[category:"), let endIndex = rawNote.firstIndex(of: "]") {
            let catId = String(rawNote[rawNote.index(rawNote.startIndex, offsetBy: 10)..<endIndex])
            if let cat = Category.all.first(where: { $0.id == catId }) {
                s.categoryId = cat.id
                s.categoryName = cat.name
                s.categoryIcon = cat.icon
                s.categoryColor = cat.color
            }
            let remaining = String(rawNote[rawNote.index(after: endIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            s.cleanNote = remaining.isEmpty ? nil : remaining
        } else {
            s.cleanNote = rawNote.isEmpty ? nil : rawNote
        }

        // Keep raw note for backward compat
        if let note = tx.note, !note.isEmpty {
            s.note = note
        }

        return s
    }
}

// MARK: - Transaction Detail Helpers

/// Helper utilities for transaction detail calculations
enum TransactionDetailHelpers {

    static func personDisplayName(for split: TransactionSplit) -> String {
        guard let person = split.owedBy else { return "Unknown" }
        if CurrentUser.isCurrentUser(person.id) { return "You" }
        return person.displayName
    }

    static func splitAmountColor(for split: TransactionSplit, isCurrentUserAPayer: Bool) -> Color {
        guard let person = split.owedBy else { return AppColors.textPrimary }
        if CurrentUser.isCurrentUser(person.id) {
            return isCurrentUserAPayer ? AppColors.textSecondary : AppColors.negative
        } else {
            return isCurrentUserAPayer ? AppColors.positive : AppColors.textSecondary
        }
    }

    static func payerName(effectivePayers: [(personId: UUID?, amount: Double)], payer: Person?) -> String {
        if effectivePayers.count <= 1 {
            if let payer = payer, CurrentUser.isCurrentUser(payer.id) {
                return "You"
            }
            return payer?.displayName ?? "Unknown"
        }
        let isUserAPayer = effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer {
            return "You +\(effectivePayers.count - 1) others"
        }
        return "\(effectivePayers.count) people"
    }

    static func participantCount(effectivePayers: [(personId: UUID?, amount: Double)], splits: [TransactionSplit]) -> Int {
        var participants = Set<UUID>()
        for payer in effectivePayers {
            if let id = payer.personId { participants.insert(id) }
        }
        for split in splits {
            if let owedById = split.owedBy?.id { participants.insert(owedById) }
        }
        return max(participants.count, 1)
    }

    static func userNetAmount(effectivePayers: [(personId: UUID?, amount: Double)], splits: [TransactionSplit]) -> Double {
        let userPaid = effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = splits
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    static func netAmountColor(for netAmount: Double) -> Color {
        if netAmount > 0.01 { return AppColors.positive }
        if netAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    static func creatorName(transaction: FinancialTransaction) -> String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id, CurrentUser.isCurrentUser(creatorId) {
            return "You"
        }
        return creator?.displayName ?? "Unknown"
    }
}
