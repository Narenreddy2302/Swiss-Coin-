//
//  GroupTransactionCardView.swift
//  Swiss Coin
//
//  Transaction card view for group context showing user's net impact.
//

import SwiftUI

struct GroupTransactionCardView: View {
    let transaction: FinancialTransaction
    let group: UserGroup
    var onEdit: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    // MARK: - Computed Properties

    /// User's net position: paid - owed. Positive = others owe you.
    private var userNetAmount: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }

        if payers.count <= 1 {
            if isUserAPayer { return "You" }
            return transaction.payer?.firstName ?? "Unknown"
        }

        if isUserAPayer {
            return "You +\(payers.count - 1)"
        }
        return "\(payers.count) payers"
    }

    private var amountText: String {
        let prefix = userNetAmount > 0.01 ? "+" : ""
        return "\(prefix)\(CurrencyFormatter.format(abs(userNetAmount)))"
    }

    private var amountColor: Color {
        if userNetAmount > 0.01 { return AppColors.positive }
        if userNetAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    private var splitCount: Int {
        (transaction.splits as? Set<TransactionSplit>)?.count ?? 0
    }

    private var splitCountText: String {
        splitCount == 1 ? "1 Person" : "\(splitCount) People"
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var dateText: String {
        guard let date = transaction.date else { return "" }
        return DateFormatter.mediumDate.string(from: date)
    }

    private var metaText: String {
        "\(dateText) | By \(payerName)"
    }

    private var payerInitials: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer { return CurrentUser.initials }
        return transaction.payer?.initials ?? "?"
    }

    private var payerColorHex: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer { return CurrentUser.defaultColorHex }
        return transaction.payer?.colorHex ?? CurrentUser.defaultColorHex
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ConversationAvatarView(
                initials: payerInitials,
                colorHex: payerColorHex
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(metaText)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(amountText)
                    .font(AppTypography.financialDefault())
                    .foregroundColor(amountColor)

                (Text(totalAmountText).fontWeight(.bold) + Text(" / \(splitCountText)"))
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.transactionCardBackground)
        )
        .padding(.horizontal, Spacing.lg)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.md))
        .contextMenu {
            // Copy Amount — most common quick action
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

            if let onEdit {
                Button {
                    HapticManager.selectionChanged()
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title ?? "Expense"), \(amountText), \(metaText)")
        .accessibilityHint("Double tap and hold for options")
    }
}
