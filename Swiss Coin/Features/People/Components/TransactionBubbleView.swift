//
//  TransactionBubbleView.swift
//  Swiss Coin
//

import SwiftUI

struct TransactionBubbleView: View {
    let transaction: FinancialTransaction
    let person: Person
    let showTimestamp: Bool

    /// Net balance for this transaction: positive = person owes you
    private var pairwiseResult: Double {
        guard let currentUserId = CurrentUser.currentUserId,
              let personId = person.id else { return 0 }
        return transaction.pairwiseBalance(personA: currentUserId, personB: personId)
    }

    private var isFromUser: Bool {
        pairwiseResult >= 0
    }

    private var displayAmount: Double {
        abs(pairwiseResult)
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
                        .foregroundColor(AppColors.textPrimary)

                    Text(amountText)
                        .font(AppTypography.amountSmall())
                        .foregroundColor(AppColors.textSecondary)
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
