//
//  TransactionDetailSheet.swift
//  Swiss Coin
//
//  Receipt-style transaction detail sheet matching the app's design language.
//  Shows full transaction breakdown with Edit and Delete action buttons.
//

import SwiftUI

struct TransactionDetailSheet: View {
    @ObservedObject var transaction: FinancialTransaction
    let person: Person?
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Cached State

    @State private var cachedEffectivePayers: [(personId: UUID?, amount: Double)] = []
    @State private var cachedSplits: [TransactionSplit] = []
    @State private var payerName = ""
    @State private var creatorName = ""
    @State private var participantCount = 1
    @State private var userNetAmount: Double = 0
    @State private var formattedReceiptDate = ""

    init(transaction: FinancialTransaction, person: Person? = nil, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.transaction = transaction
        self.person = person
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        cachedEffectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var netAmountColor: Color {
        TransactionDetailHelpers.netAmountColor(for: userNetAmount)
    }

    private var headerSubtitle: String {
        "\(CurrencyFormatter.format(transaction.amount)) / \(participantCount) People"
    }

    private func recomputeCachedState() {
        let payers = transaction.effectivePayers
        cachedEffectivePayers = payers
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        cachedSplits = splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
        payerName = TransactionDetailHelpers.payerName(effectivePayers: payers, payer: transaction.payer)
        creatorName = TransactionDetailHelpers.creatorName(transaction: transaction)
        participantCount = TransactionDetailHelpers.participantCount(effectivePayers: payers, splits: cachedSplits)
        userNetAmount = TransactionDetailHelpers.userNetAmount(effectivePayers: payers, splits: cachedSplits)
        formattedReceiptDate = transaction.date?.receiptFormatted ?? "Unknown date"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                receiptHeroHeader

                sheetDottedSeparator

                receiptPaymentSection
                    .padding(.vertical, Spacing.lg)

                if !cachedSplits.isEmpty {
                    sheetDottedSeparator
                    receiptSplitBreakdown
                        .padding(.vertical, Spacing.lg)
                }

                if let note = transaction.note, !note.isEmpty {
                    sheetDottedSeparator
                    noteSection(note: note)
                }

                actionButtonsSection
                    .padding(.top, Spacing.xl)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackground(AppColors.cardBackground)
        .onAppear {
            recomputeCachedState()
            HapticManager.lightTap()
        }
        .onChange(of: transaction.amount) { recomputeCachedState() }
        .onChange(of: transaction.title) { recomputeCachedState() }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { HapticManager.tap() }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Receipt Hero Header

    private var receiptHeroHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
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
                    sheetKeyValueRow(
                        label: "Paid by",
                        value: CurrentUser.isCurrentUser(tp.paidBy?.id)
                            ? "You" : (tp.paidBy?.displayName ?? "Unknown")
                    )
                }
            } else {
                sheetKeyValueRow(label: "Paid by", value: payerName)
            }

            sheetKeyValueRow(label: "Created by", value: creatorName)
            sheetKeyValueRow(label: "Participants", value: "\(participantCount) People")

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
                sheetKeyValueRow(label: "Group", value: group.name ?? "Unknown Group")
            }
        }
    }

    // MARK: - Receipt Split Breakdown

    private var receiptSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            ForEach(cachedSplits, id: \.objectID) { split in
                HStack {
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

            sheetDottedSeparator

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

            sheetDottedSeparator
        }
    }

    // MARK: - Note Section

    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("NOTE")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.md)

            Text(note)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                HapticManager.tap()
                if let onEdit {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onEdit()
                    }
                } else {
                    showingEditSheet = true
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

            Button {
                HapticManager.tap()
                if onDelete != nil {
                    showingDeleteAlert = true
                } else {
                    showingDeleteAlert = true
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.negative.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }

    // MARK: - Dotted Separator

    private var sheetDottedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(AppColors.separator)
            .frame(height: 1)
    }

    // MARK: - Helpers

    private func sheetKeyValueRow(label: String, value: String) -> some View {
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

    // MARK: - Delete Action

    private func performDelete() {
        if let onDelete {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDelete()
            }
        } else {
            HapticManager.delete()

            if let splits = transaction.splits as? Set<TransactionSplit> {
                splits.forEach { viewContext.delete($0) }
            }
            if let payers = transaction.payers as? Set<TransactionPayer> {
                payers.forEach { viewContext.delete($0) }
            }
            viewContext.delete(transaction)

            do {
                try viewContext.save()
                HapticManager.success()
                dismiss()
            } catch {
                viewContext.rollback()
                HapticManager.error()
                errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}
