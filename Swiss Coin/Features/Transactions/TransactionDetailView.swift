//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Transaction detail page using a flat, form-style layout that mirrors
//  AddTransactionView with read-only data displays.
//

import CoreData
import os
import SwiftUI

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false

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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                transactionNameDisplay
                dateAndAmountDisplay
                paidByDisplay
                splitWithDisplay
                splitMethodDisplay
                breakdownDisplay
                noteDisplay
                netBalanceSummary
                actionButtons
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Section 1: Transaction Name Display

    private var transactionNameDisplay: some View {
        Text(snapshot.title)
            .font(AppTypography.bodyLarge())
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }

    // MARK: - Section 2: Date & Amount Display

    private var dateAndAmountDisplay: some View {
        HStack(spacing: 0) {
            Text(snapshot.formattedDate)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Divider()
                .frame(height: 28)
                .padding(.horizontal, Spacing.md)

            Text(CurrencyFormatter.symbol(for: snapshot.currencyCode))
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textSecondary)

            Text(CurrencyFormatter.formatDecimal(snapshot.totalAmount, currencyCode: snapshot.currencyCode))
                .font(AppTypography.financialLarge())
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackgroundElevated)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Section 3: Paid By Display

    @ViewBuilder
    private var paidByDisplay: some View {
        if !snapshot.sortedPayers.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Paid By:")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(snapshot.sortedPayers, id: \.name) { payer in
                            Text(payer.name)
                                .font(AppTypography.labelSmall())
                                .foregroundColor(AppColors.buttonForeground)
                                .lineLimit(1)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.buttonBackground)
                                .cornerRadius(CornerRadius.full)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
    }

    // MARK: - Section 4: Split With Display

    @ViewBuilder
    private var splitWithDisplay: some View {
        if !snapshot.sortedSplits.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Split with:")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(snapshot.sortedSplits, id: \.objectID) { split in
                            Text(split.name)
                                .font(AppTypography.labelSmall())
                                .foregroundColor(AppColors.buttonForeground)
                                .lineLimit(1)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.buttonBackground)
                                .cornerRadius(CornerRadius.full)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
    }

    // MARK: - Section 5: Split Method Display

    private var splitMethodDisplay: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split Method:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: Spacing.sm) {
                ForEach(SplitMethod.allCases) { method in
                    let isSelected = method.rawValue == (transaction.splitMethod ?? "equal")

                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: method.systemImage)
                            .font(.system(size: IconSize.lg, weight: .medium))
                            .foregroundColor(isSelected ? AppColors.onAccent : AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: ButtonHeight.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                            )

                        Text(method.displayName)
                            .font(AppTypography.caption())
                            .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }

    // MARK: - Section 6: Breakdown Display

    @ViewBuilder
    private var breakdownDisplay: some View {
        if !snapshot.sortedSplits.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Breakdown:")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                VStack(spacing: Spacing.sm) {
                    ForEach(snapshot.sortedSplits, id: \.objectID) { split in
                        HStack {
                            Text(split.name)
                                .font(AppTypography.bodyDefault())
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            HStack(spacing: Spacing.xs) {
                                Text(CurrencyFormatter.symbol(for: snapshot.currencyCode))
                                    .font(AppTypography.bodyDefault())
                                    .foregroundColor(AppColors.textSecondary)

                                Text(CurrencyFormatter.formatDecimal(split.amount, currencyCode: snapshot.currencyCode))
                                    .font(AppTypography.financialDefault())
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(minWidth: 50, alignment: .trailing)
                            }
                        }
                    }

                    Divider()
                        .padding(.top, Spacing.sm)

                    HStack {
                        Text("Total")
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        HStack(spacing: Spacing.xs) {
                            Text(CurrencyFormatter.symbol(for: snapshot.currencyCode))
                                .font(AppTypography.bodyDefault())
                                .foregroundColor(AppColors.textSecondary)

                            Text(CurrencyFormatter.formatDecimal(snapshot.totalAmount, currencyCode: snapshot.currencyCode))
                                .font(AppTypography.financialDefault())
                                .foregroundColor(AppColors.textPrimary)
                                .frame(minWidth: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 7: Note Display (Conditional)

    @ViewBuilder
    private var noteDisplay: some View {
        if let note = snapshot.note {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Note:")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(note)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(AppColors.cardBackgroundElevated)
                    .cornerRadius(CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Section 8: Net Balance Summary

    private var netBalanceSummary: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: snapshot.userNetAmount > 0.01
                ? "arrow.up.right.circle.fill"
                : snapshot.userNetAmount < -0.01
                    ? "arrow.down.left.circle.fill"
                    : "checkmark.circle.fill")
                .font(.system(size: IconSize.sm))
                .foregroundColor(snapshot.netAmountColor)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(snapshot.statusText)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(snapshot.paymentSummaryText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(FinancialFormatter.signedCurrency(snapshot.userNetAmount, currencyCode: snapshot.currencyCode))
                .font(AppTypography.financialLarge())
                .foregroundColor(snapshot.netAmountColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(snapshot.netAmountColor.opacity(0.08))
        )
    }

    // MARK: - Section 9: Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
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
                HapticManager.tap()
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
