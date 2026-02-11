//
//  TransactionDetailSheet.swift
//  Swiss Coin
//
//  Detailed view of a transaction showing full breakdown.
//  Uses the same receipt-style layout as TransactionExpandedView for consistency.
//

import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: FinancialTransaction
    let person: Person?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Staggered Reveal State

    @State private var showHeader = false
    @State private var showDetails = false
    @State private var showSplits = false

    // MARK: - Memoized Data

    @State private var memoizedSplits: [TransactionSplit] = []
    @State private var memoizedEffectivePayers: [(personId: UUID?, amount: Double)] = []

    init(transaction: FinancialTransaction, person: Person? = nil) {
        self.transaction = transaction
        self.person = person
    }

    // MARK: - Computed Properties

    private var isCurrentUserAPayer: Bool {
        memoizedEffectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        TransactionDetailHelpers.payerName(effectivePayers: memoizedEffectivePayers, payer: transaction.payer)
    }

    private var creatorName: String {
        TransactionDetailHelpers.creatorName(transaction: transaction)
    }

    private var participantCount: Int {
        TransactionDetailHelpers.participantCount(effectivePayers: memoizedEffectivePayers, splits: memoizedSplits)
    }

    private var userNetAmount: Double {
        TransactionDetailHelpers.userNetAmount(effectivePayers: memoizedEffectivePayers, splits: memoizedSplits)
    }

    private var netAmountColor: Color {
        TransactionDetailHelpers.netAmountColor(for: userNetAmount)
    }

    private var formattedReceiptDate: String {
        transaction.date?.receiptFormatted ?? "Unknown date"
    }

    private var headerSubtitle: String {
        "\(CurrencyFormatter.format(transaction.amount)) / \(participantCount) People"
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                receiptHeroHeader
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader ? 0 : 8)

                dottedSeparator
                    .opacity(showHeader ? 1 : 0)

                receiptPaymentSection
                    .padding(.vertical, Spacing.lg)
                    .opacity(showDetails ? 1 : 0)
                    .offset(y: showDetails ? 0 : 8)

                if !memoizedSplits.isEmpty {
                    dottedSeparator
                        .opacity(showSplits ? 1 : 0)
                    receiptSplitBreakdown
                        .padding(.vertical, Spacing.lg)
                        .opacity(showSplits ? 1 : 0)
                        .offset(y: showSplits ? 0 : 8)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.cardBackground)
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            refreshMemoizedData()
            HapticManager.lightTap()
            triggerStaggeredReveal()
        }
    }

    // MARK: - Staggered Reveal

    private func triggerStaggeredReveal() {
        let base = AppAnimation.staggerBaseDelay
        let interval = AppAnimation.staggerInterval

        withAnimation(AppAnimation.contentReveal.delay(base)) {
            showHeader = true
        }
        withAnimation(AppAnimation.contentReveal.delay(base + interval)) {
            showDetails = true
        }
        withAnimation(AppAnimation.contentReveal.delay(base + interval * 2)) {
            showSplits = true
        }
    }

    // MARK: - Receipt Hero Header

    private var receiptHeroHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)

                Spacer(minLength: Spacing.md)

                Text(CurrencyFormatter.formatAbsolute(userNetAmount))
                    .font(AppTypography.financialLarge())
                    .foregroundColor(netAmountColor)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(formattedReceiptDate)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Spacer(minLength: Spacing.md)

                Text(headerSubtitle)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Receipt Payment Section

    private var receiptPaymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PAYMENT")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                let sortedPayers = payerSet.sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                ForEach(sortedPayers, id: \.objectID) { tp in
                    receiptKeyValueRow(
                        label: "Paid by",
                        value: CurrentUser.isCurrentUser(tp.paidBy?.id)
                            ? "You" : (tp.paidBy?.displayName ?? "Unknown")
                    )
                }
            } else {
                receiptKeyValueRow(label: "Paid by", value: payerName)
            }

            receiptKeyValueRow(label: "Created by", value: creatorName)
            receiptKeyValueRow(label: "Participants", value: "\(participantCount) People")

            HStack {
                Text("Split method")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    if let method = splitMethod {
                        Text(method.icon)
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equally")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            if let group = transaction.group {
                receiptKeyValueRow(label: "Group", value: group.name ?? "Unknown Group")
            }
        }
    }

    // MARK: - Receipt Split Breakdown

    private var receiptSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            ForEach(memoizedSplits, id: \.objectID) { split in
                splitRow(for: split)
            }

            dottedSeparator

            HStack {
                Text("Total Balance")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Text(CurrencyFormatter.formatDecimal(transaction.amount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            dottedSeparator
        }
    }

    // MARK: - Split Row with Avatar

    private func splitRow(for split: TransactionSplit) -> some View {
        let person = split.owedBy
        let isMe = CurrentUser.isCurrentUser(person?.id)
        let colorHex = person?.colorHex ?? CurrentUser.defaultColorHex
        let displayInitials = isMe ? CurrentUser.initials : (person?.initials ?? "?")

        return HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.15))
                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                .overlay(
                    Text(displayInitials)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: colorHex))
                )

            Text(TransactionDetailHelpers.personDisplayName(for: split))
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: Spacing.xs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Text(CurrencyFormatter.formatDecimal(split.amount))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }

    // MARK: - Dotted Separator

    private var dottedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(AppColors.separator)
            .frame(height: 1)
    }

    // MARK: - Helpers

    private func receiptKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func refreshMemoizedData() {
        memoizedEffectivePayers = transaction.effectivePayers
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        memoizedSplits = splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }
}
