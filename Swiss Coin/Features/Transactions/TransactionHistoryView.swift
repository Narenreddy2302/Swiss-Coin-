import CoreData
import SwiftUI

struct TransactionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)],
        animation: .default)
    private var transactions: FetchedResults<FinancialTransaction>

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(uiColor: .secondarySystemBackground))
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { transactions[$0] }.forEach { transaction in
                // Delete associated splits first
                if let splits = transaction.splits as? Set<TransactionSplit> {
                    splits.forEach { viewContext.delete($0) }
                }
                // Delete the transaction
                viewContext.delete(transaction)
            }
            
            do {
                try viewContext.save()
                HapticManager.success()
            } catch {
                viewContext.rollback()
                HapticManager.error()
                print("Error deleting transactions: \(error.localizedDescription)")
            }
        }
    }
}
