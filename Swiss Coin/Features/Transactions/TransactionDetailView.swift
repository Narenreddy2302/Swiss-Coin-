//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Redesigned transaction detail page — clean, modern card-based layout
//  with hero amount, status badge, details card, and split breakdown.
//

import CoreData
import SwiftUI

// MARK: - Unified Transaction Detail Sheet

struct TransactionExpandedView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TransactionDetailContent()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(CornerRadius.xl)
            .presentationBackground(AppColors.backgroundSecondary)
    }
}

// MARK: - NavigationLink Detail

struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TransactionDetailContent()
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
    }
}

// MARK: - Shared Transaction Detail Content

private struct TransactionDetailContent: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                heroSection

                statusBadge

                detailsCard

                splitBreakdownCard

                actionButtons
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("$250.00")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(-0.5)
                .foregroundColor(AppColors.textPrimary)

            Text("Dinner at Restaurant")
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textSecondary)

            Text("Jan 15, 2025 • 7:30 PM")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text("You are owed $75.00")
            .font(AppTypography.labelLarge())
            .foregroundColor(AppColors.positive)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.positive.opacity(0.12))
            )
            .padding(.bottom, Spacing.xs)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, Spacing.lg)

            // Paid by
            detailRow(label: "Paid by", value: "You", trailingBadge: "$250.00")
            cardDivider

            // Split method
            detailRow(label: "Split method", value: "Equal")
            cardDivider

            // Group
            detailRow(label: "Group", value: "Weekend Trip")
            cardDivider

            // Note
            detailRow(label: "Note", value: "Birthday celebration dinner")
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private func detailRow(label: String, value: String, trailingBadge: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack(spacing: Spacing.sm) {
                Text(value)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                if let badge = trailingBadge {
                    Text(badge)
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.accent.opacity(0.12))
                        )
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 0.5)
    }

    // MARK: - Split Breakdown Card

    private var splitBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Split Breakdown")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, Spacing.lg)

            splitRow(initials: "ME", name: "You", amount: "$62.50", color: AppColors.accent)
            cardDivider
            splitRow(initials: "AJ", name: "Alex Johnson", amount: "$62.50", color: .blue)
            cardDivider
            splitRow(initials: "SW", name: "Sarah Wilson", amount: "$62.50", color: .purple)
            cardDivider
            splitRow(initials: "MC", name: "Mike Chen", amount: "$62.50", color: .teal)
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private func splitRow(initials: String, name: String, amount: String, color: Color) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )

            Text(name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(amount)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Button {
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Transaction")
                        .font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }

            Button {
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete Transaction")
                        .font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.negative.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Line Shape (used by other files)

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Precomputed Transaction State (used by other files)

struct TransactionSnapshot {
    var title: String = "Unknown"
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
    var sortedPayers: [(name: String, amount: Double, isUser: Bool)] = []
    var sortedSplits: [(objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []

    var netAmountColor: Color {
        if userNetAmount > 0.01 { return AppColors.positive }
        if userNetAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    var directionIcon: String {
        userNetAmount > 0.01 ? "arrow.up.right" : "arrow.down.left"
    }

    var statusText: String {
        if userNetAmount > 0.01 { return "You are owed" }
        if userNetAmount < -0.01 { return "You owe" }
        return "Settled"
    }

    static func build(from tx: FinancialTransaction) -> TransactionSnapshot {
        var s = TransactionSnapshot()
        s.title = tx.title ?? "Unknown"
        s.totalAmount = tx.amount

        if let date = tx.date {
            s.formattedDate = date.receiptFormatted
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            s.formattedTime = tf.string(from: date)
        } else {
            s.formattedDate = "Unknown date"
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
                            amount: tp.amount,
                            isUser: isUser)
                }
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

// MARK: - Shared Transaction Detail Helpers (used by other files)

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
