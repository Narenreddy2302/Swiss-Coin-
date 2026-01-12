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
                        TransactionRow(transaction: transaction)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { transactions[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print(error)
            }
        }
    }
}
