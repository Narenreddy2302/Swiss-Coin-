//
//  EnhancedTransactionCardView.swift
//  Swiss Coin
//
//  Professional receipt-style transaction card for conversation timeline.
//  Matches the design with cream background, dot grid, and clean layout.
//

import SwiftUI
import CoreData

struct EnhancedTransactionCardView: View {
    let transaction: FinancialTransaction
    let person: Person
    var onEdit: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onComment: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Computed Properties

    private var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        AppShadow.card(for: colorScheme)
    }

    /// Net balance for this transaction from current user's perspective
    /// Positive = user is owed money (orange), Negative = user owes money (green)
    private var pairwiseResult: Double {
        guard let currentUserId = CurrentUser.currentUserId,
              let personId = person.id else { return 0 }
        return transaction.pairwiseBalance(personA: currentUserId, personB: personId)
    }

    private var isUserPayer: Bool {
        pairwiseResult > 0
    }

    private var isUserOwing: Bool {
        pairwiseResult < 0
    }

    private var displayAmount: Double {
        abs(pairwiseResult)
    }

    /// Amount color: Orange when user is owed (positive), Green when user owes (negative)
    private var amountColor: Color {
        if abs(pairwiseResult) < 0.01 { return AppColors.neutral }
        return isUserPayer ? AppColors.positive : AppColors.negative
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }

        if payers.count <= 1 {
            if isUserAPayer { return "You" }
            return transaction.payer?.name ?? person.name ?? "Someone"
        }

        if isUserAPayer {
            return "You +\(payers.count - 1)"
        }
        return "\(payers.count) payers"
    }

    private var creatorName: String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id, CurrentUser.isCurrentUser(creatorId) {
            return "You"
        }
        return creator?.name ?? "Someone"
    }

    private var sortedSplits: [TransactionSplit] {
        let splitsSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitsSet.sorted { s1, s2 in
            let isMe1 = CurrentUser.isCurrentUser(s1.owedBy?.id)
            let isMe2 = CurrentUser.isCurrentUser(s2.owedBy?.id)
            if isMe1 != isMe2 { return isMe1 }
            return (s1.owedBy?.name ?? "") < (s2.owedBy?.name ?? "")
        }
    }

    private var commentCount: Int {
        (transaction.comments as? Set<ChatMessage>)?.count ?? 0
    }

    private var splitCount: Int {
        (transaction.splits as? Set<TransactionSplit>)?.count ?? 0
    }

    private var splitCountText: String {
        splitCount == 1 ? "1 Person" : "\(splitCount) People"
    }

    private var splitMethodDisplay: String {
        switch transaction.splitMethod {
        case "equal": return "= Equally"
        case "amount": return "$ By Amount"
        case "percentage": return "% By Percentage"
        case "shares": return "÷ By Shares"
        case "adjustment": return "± Adjusted"
        default: return "= Equally"
        }
    }

    private var dateText: String {
        guard let date = transaction.date else { return "" }
        return date.receiptFormatted
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var totalBalance: Double {
        (transaction.splits as? Set<TransactionSplit> ?? []).reduce(0.0) { $0 + $1.amount }
    }

    private var isSettled: Bool {
        abs(totalBalance - transaction.amount) < 0.01
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header: Title + Amount
            headerSection

            divider

            // Payment Info Section
            paymentSection

            divider

            // Split Breakdown Section
            splitBreakdownSection

            divider

            // Total Balance
            totalBalanceRow

            divider

            // Action Buttons
            actionButtons
        }
        .padding(.vertical, Spacing.lg)
        .background(AppColors.transactionCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(
            color: cardShadow.color,
            radius: cardShadow.radius,
            x: cardShadow.x,
            y: cardShadow.y
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title ?? "Expense"), \(CurrencyFormatter.format(displayAmount)), \(dateText)")
        .accessibilityHint("Double tap and hold for options")
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: Spacing.sm)

                Text(CurrencyFormatter.format(displayAmount))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(amountColor)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(dateText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: Spacing.sm)

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Payment Section

    @ViewBuilder
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Section Label
            Text("PAYMENT")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)
                .padding(.bottom, Spacing.xxs)

            VStack(spacing: Spacing.xs) {
                receiptRow(label: "Paid by", value: payerName)
                receiptRow(label: "Created by", value: creatorName)
                receiptRow(label: "Participants", value: splitCountText)
                receiptRow(label: "Split method", value: splitMethodDisplay)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Split Breakdown Section

    @ViewBuilder
    private var splitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Section Label
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .tracking(0.5)
                .padding(.bottom, Spacing.xxs)

            VStack(spacing: Spacing.xs) {
                ForEach(sortedSplits, id: \.self) { split in
                    let owedBy = split.owedBy
                    let isMe = CurrentUser.isCurrentUser(owedBy?.id)
                    let name = isMe ? "You" : (owedBy?.name ?? "Unknown")

                    splitRow(name: name, amount: split.amount, isCurrentUser: isMe)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Total Balance Row

    @ViewBuilder
    private var totalBalanceRow: some View {
        HStack {
            Text("Total Balance")
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatDecimal(abs(transaction.amount - totalBalance)))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(isSettled ? AppColors.positive : AppColors.textPrimary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            // Comment Button - Orange filled
            Button {
                HapticManager.selectionChanged()
                onComment?()
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text("Comment")
                    if commentCount > 0 {
                        Text("\(commentCount)")
                            .font(AppTypography.caption())
                    }
                }
                .font(AppTypography.buttonSmall())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(AppColors.accent)
                )
            }

            // Edit Button - Outlined
            Button {
                HapticManager.selectionChanged()
                onEdit?()
            } label: {
                Text("Edit")
                    .font(AppTypography.buttonSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(AppColors.border, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(AppColors.transactionCardBackground)
                            )
                    )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func receiptRow(label: String, value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func splitRow(name: String, amount: Double, isCurrentUser: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(name)
                .font(isCurrentUser ? AppTypography.labelDefault() : AppTypography.bodySmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatDecimal(amount))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }

    private var divider: some View {
        AppColors.transactionCardDivider
            .frame(height: 0.5)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            UIPasteboard.general.string = CurrencyFormatter.format(transaction.amount)
            HapticManager.copyAction()
        } label: {
            Label("Copy Amount", systemImage: "doc.on.doc")
        }

        if let onViewDetails {
            Button {
                HapticManager.selectionChanged()
                onViewDetails()
            } label: {
                Label("View Details", systemImage: "doc.text.magnifyingglass")
            }
        }

        if let onUndo {
            Button {
                HapticManager.undoAction()
                onUndo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
        }

        if onDelete != nil {
            Divider()
            Button(role: .destructive) {
                HapticManager.destructiveAction()
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Transaction Card") {
    let context = PersistenceController.shared.container.viewContext

    let person: Person = {
        let p = Person(context: context)
        p.id = UUID()
        p.name = "Mike Harvey"
        p.colorHex = "#F35B16"
        return p
    }()

    let transaction: FinancialTransaction = {
        let t = FinancialTransaction(context: context)
        t.id = UUID()
        t.title = "Dinner at Naples"
        t.amount = 40.0
        t.date = Date()
        t.splitMethod = "equal"
        t.payer = person
        t.createdBy = person

        let split1 = TransactionSplit(context: context)
        split1.amount = 10.0
        split1.owedBy = person
        split1.transaction = t

        let split2 = TransactionSplit(context: context)
        split2.amount = 10.0
        split2.owedBy = person
        split2.transaction = t

        return t
    }()

    EnhancedTransactionCardView(
        transaction: transaction,
        person: person,
        onEdit: {},
        onComment: {}
    )
    .padding()
    .background(AppColors.backgroundSecondary)
}
