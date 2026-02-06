//
//  TransactionBubbleView.swift
//  Swiss Coin
//

import SwiftUI

struct TransactionBubbleView: View {
    let transaction: FinancialTransaction
    let person: Person
    let showTimestamp: Bool

    private var isFromUser: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var displayAmount: Double {
        if isFromUser {
            // User paid - show what they owe you
            let splits = transaction.splits as? Set<TransactionSplit> ?? []
            if let theirSplit = splits.first(where: { $0.owedBy?.id == person.id }) {
                return theirSplit.amount
            }
            return 0
        } else {
            // They paid - show what you owe
            let splits = transaction.splits as? Set<TransactionSplit> ?? []
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
            return 0
        }
    }

    private var amountText: String {
        let formatted = CurrencyFormatter.format(displayAmount)

        if isFromUser {
            return formatted
        } else {
            return "You owe \(formatted)"
        }
    }

    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: UIScreen.main.bounds.width * 0.25)
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                // Bubble content
                VStack(alignment: .leading, spacing: 6) {
                    Text(transaction.title ?? "Unknown")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(isFromUser ? .white : AppColors.textPrimary)

                    Text(amountText)
                        .font(AppTypography.amountSmall())
                        .foregroundColor(isFromUser ? .white.opacity(0.9) : AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    BubbleShape(isFromUser: isFromUser)
                        .fill(isFromUser ? AppColors.userBubble : AppColors.otherBubble)
                )

                // Timestamp
                if showTimestamp {
                    Text(transaction.date ?? Date(), style: .time)
                        .font(AppTypography.caption2())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 4)
                }
            }

            if !isFromUser {
                Spacer(minLength: UIScreen.main.bounds.width * 0.25)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromUser {
            // Right-aligned bubble with tail on the right
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - 12))
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: rect.height - 8))
        } else {
            // Left-aligned bubble with tail on the left
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: 0, y: rect.height - 12))
            path.addLine(to: CGPoint(x: tailSize, y: rect.height - 8))
        }

        return path
    }
}
