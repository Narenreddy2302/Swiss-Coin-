//
//  FeedTransactionContent.swift
//  Swiss Coin
//
//  Transaction content for feed rows — supports compact and card display modes.
//

import SwiftUI

struct FeedTransactionContent: View {
    let transaction: FinancialTransaction
    var person: Person? = nil
    var group: UserGroup? = nil
    var cardStyle: Bool = false
    var onEdit: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onComment: (() -> Void)? = nil

    // MARK: - Computed Properties

    private var pairwiseResult: Double {
        guard let currentUserId = CurrentUser.currentUserId else { return 0 }
        if let personId = person?.id {
            return transaction.pairwiseBalance(personA: currentUserId, personB: personId)
        }
        let payers = transaction.effectivePayers
        let userPaid = payers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0.0) { $0 + $1.amount }
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        let userOwed = splitSet
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0.0) { $0 + $1.amount }
        return userPaid - userOwed
    }

    private var isUserPayer: Bool {
        pairwiseResult > 0
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if payers.count <= 1 {
            if isUserAPayer { return "You" }
            return transaction.payer?.name ?? person?.name ?? "Someone"
        }
        if isUserAPayer {
            return "You +\(payers.count - 1)"
        }
        return "\(payers.count) payers"
    }

    private var displayAmount: Double {
        abs(pairwiseResult)
    }

    private var amountColor: Color {
        if abs(pairwiseResult) < 0.01 { return AppColors.neutral }
        return isUserPayer ? AppColors.positive : AppColors.negative
    }

    private var splitCount: Int {
        let splitsSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitsSet.count
    }

    private var splitCountText: String {
        splitCount == 1 ? "1 Person" : "\(splitCount) People"
    }

    private var splitMethodName: String {
        switch transaction.splitMethod {
        case "equal": return "Equally"
        case "amount": return "By Amount"
        case "percentage": return "By Percentage"
        case "shares": return "By Shares"
        case "adjustment": return "Adjusted"
        default: return "Equally"
        }
    }

    private var splitMethodSymbol: String {
        switch transaction.splitMethod {
        case "equal": return "="
        case "amount": return "$"
        case "percentage": return "%"
        case "shares": return "÷"
        case "adjustment": return "±"
        default: return "="
        }
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var amountPrefix: String {
        if abs(pairwiseResult) < 0.01 { return "" }
        return isUserPayer ? "+" : "-"
    }

    private var creatorDisplayName: String {
        TransactionDetailHelpers.creatorName(transaction: transaction)
    }

    private var sortedSplits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.name ?? "") < ($1.owedBy?.name ?? "") }
    }

    // MARK: - Body

    var body: some View {
        if cardStyle {
            cardBody
        } else {
            compactBody
        }
    }

    // MARK: - Card Body

    @ViewBuilder
    private var cardBody: some View {
        HStack(spacing: 0) {
            // Left accent bar — contextual color
            amountColor
                .frame(width: 4)

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                cardHeader

                AppColors.transactionCardDivider
                    .frame(height: 0.5)
                    .padding(.top, Spacing.md)

                cardDetailSection
                    .padding(.top, Spacing.md)

                cardSplitBreakdown
                    .padding(.top, Spacing.lg)

                cardTotalBalance
                    .padding(.top, Spacing.sm)

                if onComment != nil || onEdit != nil {
                    cardActionButtons
                        .padding(.top, Spacing.lg)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.transactionCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(color: AppColors.shadowSubtle, radius: 6, x: 0, y: 2)
        .shadow(color: AppColors.shadowMicro, radius: 2, x: 0, y: 1)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu { contextMenuContent }
        .padding(.horizontal, Spacing.screenHorizontal)
        .onTapGesture { onViewDetails?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title ?? "Expense"), \(CurrencyFormatter.format(displayAmount)), \(transaction.date?.receiptFormatted ?? "")")
    }

    // MARK: - Card Header

    @ViewBuilder
    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(amountPrefix)\(CurrencyFormatter.format(displayAmount))")
                    .font(AppTypography.financialLarge())
                    .foregroundColor(amountColor)
            }

            HStack {
                Text(transaction.date?.receiptFormatted ?? "")
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Card Detail Section

    @ViewBuilder
    private var cardDetailSection: some View {
        VStack(spacing: Spacing.sm) {
            cardDetailRow(label: "Paid by", value: payerName)
            cardDetailRow(label: "Created by", value: creatorDisplayName)
            cardDetailRow(label: "Participants", value: splitCountText)
            cardDetailRow(label: "Split method", value: splitMethodName)
        }
    }

    @ViewBuilder
    private func cardDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Card Split Breakdown

    @ViewBuilder
    private var cardSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)
                .tracking(AppTypography.Tracking.labelSmall)
                .padding(.bottom, Spacing.xxs)

            ForEach(sortedSplits, id: \.objectID) { split in
                HStack {
                    Text(TransactionDetailHelpers.personDisplayName(for: split))
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        Text(CurrencyFormatter.currencySymbol)
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)

                        Text(CurrencyFormatter.formatDecimal(split.amount))
                            .font(AppTypography.financialSmall())
                            .foregroundColor(AppColors.textPrimary)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Card Total Balance

    @ViewBuilder
    private var cardTotalBalance: some View {
        AppColors.transactionCardDivider
            .frame(height: 0.5)

        HStack {
            Text("Total Balance")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: Spacing.sm) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.formatDecimal(transaction.amount))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Card Action Buttons

    @ViewBuilder
    private var cardActionButtons: some View {
        HStack(spacing: Spacing.md) {
            if onComment != nil {
                Button {
                    HapticManager.selectionChanged()
                    onComment?()
                } label: {
                    Text("Comment")
                        .font(AppTypography.buttonDefault())
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.button)
                                .stroke(AppColors.accent, lineWidth: 1)
                        )
                }
            }

            if onEdit != nil {
                Button {
                    HapticManager.selectionChanged()
                    onEdit?()
                } label: {
                    Text("Edit")
                        .font(AppTypography.buttonDefault())
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.button)
                                .stroke(AppColors.accent, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Compact Body (Existing Design)

    @ViewBuilder
    private var compactBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(amountPrefix)\(CurrencyFormatter.format(displayAmount))")
                    .font(AppTypography.financialDefault())
                    .foregroundColor(amountColor)
            }

            HStack(spacing: Spacing.xs) {
                Text("Paid by \(payerName)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text("\u{00B7}")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textTertiary)

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("\(splitMethodSymbol) \(splitMethodName)")
                .captionStyle()
                .foregroundColor(AppColors.textTertiary)

            if onComment != nil || onViewDetails != nil || onEdit != nil {
                HStack(spacing: Spacing.xl) {
                    if onComment != nil {
                        Button {
                            HapticManager.selectionChanged()
                            onComment?()
                        } label: {
                            Image(systemName: "bubble.right")
                                .font(.system(size: IconSize.xs))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    if onViewDetails != nil {
                        Button {
                            HapticManager.selectionChanged()
                            onViewDetails?()
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: IconSize.xs))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    if onEdit != nil {
                        Button {
                            HapticManager.selectionChanged()
                            onEdit?()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: IconSize.xs))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.top, Spacing.xxs)
            }
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contentShape(Rectangle())
        .onTapGesture { onViewDetails?() }
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title ?? "Expense"), \(CurrencyFormatter.format(displayAmount)), \(transaction.date?.receiptFormatted ?? "")")
    }

    // MARK: - Shared Context Menu

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
