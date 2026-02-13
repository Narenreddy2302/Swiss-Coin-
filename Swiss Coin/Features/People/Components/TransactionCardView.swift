//
//  TransactionCardView.swift
//  Swiss Coin
//
//  Receipt-style transaction card for the conversation timeline.
//

import SwiftUI

struct TransactionCardView: View {
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

    /// Net balance for this transaction: positive = person owes you
    private var pairwiseResult: Double {
        guard let currentUserId = CurrentUser.currentUserId,
              let personId = person.id else { return 0 }
        return transaction.pairwiseBalance(personA: currentUserId, personB: personId)
    }

    private var isUserPayer: Bool {
        pairwiseResult > 0
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

    /// Amount from user's perspective using net-position algorithm
    private var displayAmount: Double {
        abs(pairwiseResult)
    }

    private var amountColor: Color {
        if abs(pairwiseResult) < 0.01 { return AppColors.neutral }
        return isUserPayer ? AppColors.positive : AppColors.negative
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

    private var splitCount: Int {
        (transaction.splits as? Set<TransactionSplit>)?.count ?? 0
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

    private var dateText: String {
        guard let date = transaction.date else { return "" }
        return date.receiptFormatted
    }

    private var totalAmountText: String {
        CurrencyFormatter.format(transaction.amount)
    }

    /// Total balance remaining for this transaction (sum of all splits minus total should be 0)
    private var totalBalance: Double {
        let splitsTotal = (transaction.splits as? Set<TransactionSplit> ?? []).reduce(0.0) { $0 + $1.amount }
        return transaction.amount - splitsTotal
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header: Title + Amount
            headerSection

            receiptDivider

            // Payment Info Section
            paymentSection

            receiptDivider

            // Split Breakdown Section
            splitBreakdownSection

            receiptDivider

            // Total Balance
            totalBalanceRow

            receiptDivider

            // Action Buttons
            actionButtons
        }
        .padding(.vertical, Spacing.lg)
        .background(AppColors.receiptBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        .shadow(
            color: cardShadow.color,
            radius: cardShadow.radius,
            x: cardShadow.x,
            y: cardShadow.y
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: CornerRadius.card))
        .contextMenu {
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
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: Spacing.sm)

                Text(CurrencyFormatter.format(displayAmount))
                    .font(AppTypography.financialLarge())
                    .foregroundColor(amountColor)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(dateText)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: Spacing.sm)

                Text("\(totalAmountText) / \(splitCountText)")
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Payment Section

    @ViewBuilder
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            receiptRow(label: "Paid by", value: payerName)
            receiptRow(label: "Created by", value: creatorName)
            receiptRow(label: "Participants", value: splitCountText)
            receiptRow(label: "Split method", value: "\(splitMethodSymbol) \(splitMethodName)")
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Split Breakdown Section

    @ViewBuilder
    private var splitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT BREAKDOWN")
                .labelSmallStyle()
                .foregroundColor(AppColors.textTertiary)
                .padding(.bottom, Spacing.xxs)

            ForEach(sortedSplits, id: \.self) { split in
                let owedBy = split.owedBy
                let isMe = CurrentUser.isCurrentUser(owedBy?.id)
                let name = isMe ? "You" : (owedBy?.name ?? "Unknown")

                splitRow(
                    name: name,
                    amount: split.amount,
                    isBold: isMe
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Total Balance Row

    @ViewBuilder
    private var totalBalanceRow: some View {
        HStack {
            Text("Total Balance")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 14, alignment: .trailing)

            Text(CurrencyFormatter.formatDecimal(abs(totalBalance)))
                .font(AppTypography.financialSmall())
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            // Comment Button
            Button {
                HapticManager.selectionChanged()
                onComment?()
            } label: {
                Text("Comment")
                    .font(AppTypography.buttonSmall())
                    .foregroundColor(AppColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.button)
                            .fill(AppColors.accent)
                    )
            }

            // Edit Button
            Button {
                HapticManager.selectionChanged()
                onEdit?()
            } label: {
                Text("Edit")
                    .font(AppTypography.buttonSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.button)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Receipt Row Helper

    @ViewBuilder
    private func receiptRow(label: String, value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            DottedLeaderLine()
                .frame(height: 1)

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Split Row Helper

    @ViewBuilder
    private func splitRow(name: String, amount: Double, isBold: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(name)
                .font(isBold ? AppTypography.labelLarge() : AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 14, alignment: .trailing)

            Text(CurrencyFormatter.formatDecimal(amount))
                .font(AppTypography.financialSmall())
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 50, alignment: .trailing)
        }
    }

    // MARK: - Receipt Divider

    @ViewBuilder
    private var receiptDivider: some View {
        AppColors.receiptSeparator
            .frame(height: 1)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Dotted Leader Line

struct DottedLeaderLine: View {
    var color: Color = AppColors.receiptLeader

    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
            .foregroundColor(color)
    }
}

// MARK: - Dot Grid Pattern

struct DotGridPattern: View {
    var dotSpacing: CGFloat = 14
    var dotRadius: CGFloat = 0.6
    var color: Color = AppColors.receiptDot

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let dotDiameter = dotRadius * 2
            let cols = Int(size.width / dotSpacing) + 1
            let rows = Int(size.height / dotSpacing) + 1
            let shading = GraphicsContext.Shading.color(color)

            for row in 0...rows {
                let y = CGFloat(row) * dotSpacing - dotRadius
                for col in 0...cols {
                    let x = CGFloat(col) * dotSpacing - dotRadius
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dotDiameter, height: dotDiameter)),
                        with: shading
                    )
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
