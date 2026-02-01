//
//  GroupTransactionCardView.swift
//  Swiss Coin
//
//  Transaction card view for group context.
//

import SwiftUI

struct GroupTransactionCardView: View {
    let transaction: FinancialTransaction
    let group: UserGroup
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isPressed = false

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var payerName: String {
        if isUserPayer {
            return "You"
        } else {
            return transaction.payer?.firstName ?? "Someone"
        }
    }

    /// Calculate what the user's net impact is from this transaction
    private var userNetAmount: Double {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        if isUserPayer {
            // User paid - calculate how much others owe them
            var othersOwe: Double = 0
            for split in splits {
                if !CurrentUser.isCurrentUser(split.owedBy?.id) {
                    othersOwe += split.amount
                }
            }
            return othersOwe
        } else {
            // Someone else paid - user owes their share
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.person?.id) }) {
                return -mySplit.amount
            }
            return 0
        }
    }

    private var amountText: String {
        let formatted = CurrencyFormatter.format(abs(userNetAmount))

        if userNetAmount > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    private var amountColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive
        } else if userNetAmount < -0.01 {
            return AppColors.negative
        }
        return AppColors.neutral
    }

    private var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        // Count unique participants (payer + those who owe)
        var participants = Set<UUID>()
        if let payerId = transaction.payer?.id {
            participants.insert(payerId)
        }
        for split in splits {
            if let personId = split.owedBy?.id {
                participants.insert(personId)
            }
        }

        if participants.isEmpty && !splits.isEmpty {
            return splits.count
        }

        return max(participants.count, 1)
    }

    private var splitCountText: String {
        let count = splitCount
        return count == 1 ? "1 Person" : "\(count) People"
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: transaction.date ?? Date())
    }

    private var metaText: String {
        return "\(dateText) | Paid by \(payerName)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            // Left side - Title and Meta
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Untitled Transaction")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Text(metaText)
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Right side - Amount and Split Info
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
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .padding(.horizontal, Spacing.lg)
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .contextMenu {
            if onEdit != nil {
                Button {
                    HapticManager.tap()
                    onEdit?()
                } label: {
                    Label("Edit Transaction", systemImage: "pencil")
                }
            }

            Button {
                HapticManager.tap()
                // Share action
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                HapticManager.tap()
                // View details action
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            if onDelete != nil {
                Divider()

                Button(role: .destructive) {
                    HapticManager.delete()
                    onDelete?()
                } label: {
                    Label("Delete Transaction", systemImage: "trash")
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(AppAnimation.quick) {
                isPressed = pressing
            }
            if pressing {
                HapticManager.longPress()
            }
        }, perform: {})
    }
}
