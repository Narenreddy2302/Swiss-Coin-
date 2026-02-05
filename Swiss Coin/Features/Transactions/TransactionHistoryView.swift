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

    var body: some View {
        NavigationStack {
            ZStack {
                if transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
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

            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)

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
                    .font(AppTypography.subheadline())
            }
            .foregroundColor(AppColors.accent)
            .padding(.top, Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRowView(
                    transaction: transaction,
                    onEdit: nil,
                    onDelete: {
                        transactionToDelete = transaction
                        showingDeleteAlert = true
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppColors.backgroundSecondary)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Delete Logic

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { transactions[$0] }.forEach { transaction in
                deleteTransaction(transaction)
            }
        }
    }

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
