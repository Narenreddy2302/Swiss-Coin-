import CoreData
import os
import SwiftUI

// MARK: - Static Formatters (allocated once, reused across all renders)

private let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

struct TransactionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
        request.fetchBatchSize = 50
        request.relationshipKeyPathsForPrefetching = ["payer", "splits", "payers", "createdBy"]
        return request
    }(), animation: .default)
    private var transactions: FetchedResults<FinancialTransaction>

    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: FinancialTransaction?

    @State private var selectedTransaction: FinancialTransaction?

    // MARK: - Cached Computed Values (avoid O(n) per render)

    @State private var cachedGroups: [(key: String, transactions: [FinancialTransaction])] = []
    @State private var cachedTotalAmount: Double = 0
    @State private var cachedTransactionCount: Int = 0

    private func recomputeGroupedTransactions() {
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
                return monthYearFormatter.string(from: date)
            }
        }

        let order = ["Today", "Yesterday", "This Week", "This Month"]

        cachedGroups = grouped
            .sorted { first, second in
                let idx1 = order.firstIndex(of: first.key) ?? Int.max
                let idx2 = order.firstIndex(of: second.key) ?? Int.max
                if idx1 != Int.max || idx2 != Int.max {
                    return idx1 < idx2
                }
                let date1 = first.value.first?.date ?? Date.distantPast
                let date2 = second.value.first?.date ?? Date.distantPast
                return date1 > date2
            }
            .map { (key: $0.key, transactions: $0.value.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) }

        cachedTotalAmount = transactions.reduce(0) { $0 + $1.amount }
        cachedTransactionCount = transactions.count
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

            }
            .background(AppColors.backgroundSecondary)
            .sheet(isPresented: Binding(
                get: { selectedTransaction != nil },
                set: { if !$0 { selectedTransaction = nil } }
            )) {
                if let transaction = selectedTransaction {
                    TransactionExpandedView(transaction: transaction)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
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
            .onAppear { recomputeGroupedTransactions() }
            .onChange(of: transactions.count) { recomputeGroupedTransactions() }
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
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            Text("Your transaction history will appear here once you add expenses or split bills with friends.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: IconSize.sm))
                Text("Tap + to create your first transaction")
                    .font(AppTypography.labelLarge())
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
                    ForEach(cachedGroups, id: \.key) { group in
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
                Text(CurrencyFormatter.format(cachedTotalAmount))
                    .font(AppTypography.financialLarge())
                    .tracking(AppTypography.Tracking.financialLarge)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            // Transaction Count
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("Transactions")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                Text("\(cachedTransactionCount)")
                    .font(AppTypography.financialLarge())
                    .tracking(AppTypography.Tracking.financialLarge)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Transaction Section

    private func transactionSection(title: String, transactions: [FinancialTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(AppTypography.labelLarge())
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
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
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
