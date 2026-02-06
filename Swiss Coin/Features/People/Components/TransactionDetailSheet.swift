//
//  TransactionDetailSheet.swift
//  Swiss Coin
//
//  Detailed view of a transaction showing full breakdown.
//

import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: FinancialTransaction
    let person: Person?
    @Environment(\.dismiss) private var dismiss

    init(transaction: FinancialTransaction, person: Person? = nil) {
        self.transaction = transaction
        self.person = person
    }

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var payerName: String {
        if isUserPayer { return "You" }
        return transaction.payer?.name ?? "Someone"
    }

    private var creatorName: String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id, CurrentUser.isCurrentUser(creatorId) {
            return "You"
        }
        return creator?.name ?? "Someone"
    }

    private var splits: [TransactionSplit] {
        let splitsSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitsSet.sorted { ($0.owedBy?.name ?? "") < ($1.owedBy?.name ?? "") }
    }

    private var splitMethodName: String {
        switch transaction.splitMethod {
        case "equal": return "Equal"
        case "amount": return "By Amount"
        case "percentage": return "By Percentage"
        case "shares": return "By Shares"
        case "adjustment": return "Equal + Adjustments"
        default: return "Equal"
        }
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: Spacing.lg) {
                    Text(transaction.title ?? "Untitled")
                        .font(AppTypography.title2())
                        .foregroundColor(AppColors.textPrimary)

                    Text(CurrencyFormatter.format(transaction.amount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    if let date = transaction.date {
                        Text(DateFormatter.longDate.string(from: date))
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .listRowBackground(Color.clear)
            }

            // Transaction Info
            Section("Details") {
                HStack {
                    Text("Paid by")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(payerName)
                        .foregroundColor(AppColors.textPrimary)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Created by")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(creatorName)
                        .foregroundColor(AppColors.textPrimary)
                }

                HStack {
                    Text("Split method")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(splitMethodName)
                        .foregroundColor(AppColors.textPrimary)
                }

                if let group = transaction.group {
                    HStack {
                        Text("Group")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(group.name ?? "Unknown")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            // Split Breakdown
            if !splits.isEmpty {
                Section("Split Breakdown") {
                    ForEach(splits, id: \.self) { split in
                        HStack(spacing: Spacing.md) {
                            let owedByPerson = split.owedBy
                            let isMe = CurrentUser.isCurrentUser(owedByPerson?.id)

                            Circle()
                                .fill(Color(hex: owedByPerson?.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                                .overlay(
                                    Text(isMe ? "ME" : (owedByPerson?.initials ?? "?"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: owedByPerson?.colorHex ?? CurrentUser.defaultColorHex))
                                )

                            Text(isMe ? "You" : (owedByPerson?.name ?? "Unknown"))
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Text(CurrencyFormatter.format(split.amount))
                                .font(AppTypography.amountSmall())
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.vertical, Spacing.xxs)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

