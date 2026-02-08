import CoreData
import os
import SwiftUI

struct TransactionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var transactions: FetchedResults<FinancialTransaction>

    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: FinancialTransaction?

    @State private var selectedTransaction: FinancialTransaction?

    // MARK: - Grouped Transactions

    private var groupedTransactions: [(key: String, transactions: [FinancialTransaction])] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: Array(transactions)) { (transaction: FinancialTransaction) -> String in
            guard let date = transaction.date else { return "Unknown" }

            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
                return "This Week"
            } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 30 {
                return "This Month"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
        }

        // Define sort order for group keys
        let order = ["Today", "Yesterday", "This Week", "This Month"]

        return grouped
            .sorted { first, second in
                let idx1 = order.firstIndex(of: first.key) ?? Int.max
                let idx2 = order.firstIndex(of: second.key) ?? Int.max
                if idx1 != Int.max || idx2 != Int.max {
                    return idx1 < idx2
                }
                // For month-year strings, sort descending by the first transaction date
                let date1 = first.value.first?.date ?? Date.distantPast
                let date2 = second.value.first?.date ?? Date.distantPast
                return date1 > date2
            }
            .map { (key: $0.key, transactions: $0.value.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) }
    }

    // MARK: - Summary

    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    private var transactionCount: Int {
        transactions.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                        .allowsHitTesting(selectedTransaction == nil)
                }

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
                    .opacity(selectedTransaction == nil ? 1 : 0)

                // Full-screen detail overlay
                if let selected = selectedTransaction {
                    TransactionExpandedView(
                        transaction: selected,
                        selectedTransaction: $selectedTransaction
                    )
                    .zIndex(2)
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    transactionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let transaction = transactionToDelete {
                        deleteTransaction(transaction)
                    }
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.backgroundTertiary)
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                )

            Text("No Transactions Yet")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Your transaction history will appear here once you add expenses or split bills with friends.")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: IconSize.sm))
                Text("Tap + to create your first transaction")
                    .font(AppTypography.subheadlineMedium())
            }
            .foregroundColor(AppColors.accent)
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                // Summary Header
                summaryHeader

                // Grouped Transactions
                LazyVStack(spacing: Spacing.xl) {
                    ForEach(groupedTransactions, id: \.key) { group in
                        transactionSection(title: group.key, transactions: group.transactions)
                    }
                }

                Spacer()
                    .frame(height: Spacing.section + Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: Spacing.lg) {
            // Total Amount
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Total")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                Text(CurrencyFormatter.format(totalAmount))
                    .font(AppTypography.amountLarge())
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            // Transaction Count
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("Transactions")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                Text("\(transactionCount)")
                    .font(AppTypography.amountLarge())
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Transaction Section

    private func transactionSection(title: String, transactions: [FinancialTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(transactions.count)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            // Transaction rows
            VStack(spacing: 0) {
                ForEach(transactions) { transaction in
                    TransactionRowView(
                        transaction: transaction,
                        onEdit: nil,
                        onDelete: {
                            transactionToDelete = transaction
                            showingDeleteAlert = true
                        },
                        selectedTransaction: $selectedTransaction
                    )

                    if transaction.id != transactions.last?.id {
                        Divider()
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
        }
    }

    // MARK: - Delete Logic

    private func deleteTransaction(_ transaction: FinancialTransaction) {
        // Delete associated splits first
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }
        // Delete the transaction
        viewContext.delete(transaction)

        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.transactions.error("Failed to delete transaction: \(error.localizedDescription)")
        }
    }
}
