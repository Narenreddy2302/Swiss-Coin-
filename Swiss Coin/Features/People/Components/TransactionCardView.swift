//
//  TransactionCardView.swift
//  Swiss Coin
//
//  iMessage-style transaction card for person conversation context.
//

import SwiftUI

struct TransactionCardView: View {
    let transaction: FinancialTransaction
    let person: Person
    var onEdit: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    // MARK: - Computed Properties

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var isPersonPayer: Bool {
        transaction.payer?.id == person.id
    }

    private var payerName: String {
        if isUserPayer { return "You" }
        if isPersonPayer { return person.firstName }
        return transaction.payer?.firstName ?? "Unknown"
    }

    /// Amount from user's perspective: positive = they owe you, negative = you owe
    private var displayAmount: Double {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []
        if isUserPayer {
            // User paid — show what person owes
            if let theirSplit = splits.first(where: { $0.owedBy?.id == person.id }) {
                return theirSplit.amount
            }
            return 0
        } else if isPersonPayer {
            // Person paid — show what user owes
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
            return 0
        } else {
            // Third party paid — show user's split if any
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
            return 0
        }
    }

    private var amountText: String {
        let prefix = isUserPayer ? "+" : ""
        return "\(prefix)\(CurrencyFormatter.format(displayAmount))"
    }

    private var amountColor: Color {
        isUserPayer ? AppColors.positive : AppColors.negative
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

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(metaText)
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(amountText)
                    .font(AppTypography.amount())
                    .foregroundColor(amountColor)

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .padding(.horizontal, Spacing.lg)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.md))
        .contextMenu {
            // Copy Amount — most common quick action
            Button {
                UIPasteboard.general.string = CurrencyFormatter.format(transaction.amount)
                HapticManager.tap()
            } label: {
                Label("Copy Amount", systemImage: "doc.on.doc")
            }

            if let onViewDetails {
                Button {
                    HapticManager.tap()
                    onViewDetails()
                } label: {
                    Label("View Details", systemImage: "doc.text.magnifyingglass")
                }
            }

            if let onEdit {
                Button {
                    HapticManager.tap()
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onUndo {
                Button {
                    HapticManager.tap()
                    onUndo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
            }

            if onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    HapticManager.delete()
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
