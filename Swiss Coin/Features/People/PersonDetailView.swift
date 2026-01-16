import CoreData
import SwiftUI

struct PersonDetailView: View {
    @ObservedObject var person: Person
    @State private var showingAddTransaction = false

    var body: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? "#34C759"))  // Default generic green
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(person.initials)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 10)

                    VStack(spacing: 4) {
                        Text(person.name ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let phone = person.phoneNumber {
                            Text(phone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Action Buttons (Simulating "Follow" / "Latest Episode")
                    HStack(spacing: 12) {
                        ActionHeaderButton(
                            title: "Pay",
                            icon: "arrow.up.right.circle.fill",
                            color: Color.green
                        ) {
                            showingAddTransaction = true
                        }

                        ActionHeaderButton(
                            title: "Request",
                            icon: "arrow.down.left.circle.fill",
                            color: Color.green
                        ) {
                            showingAddTransaction = true
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, 20)
            }
            .sheet(isPresented: $showingAddTransaction) {
                QuickActionSheetPresenter(initialPerson: person)
            }

            // Transactions List
            Section(header: Text("Transactions")) {
                if combinedTransactions.isEmpty {
                    Text("No transactions yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(combinedTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    // Helper to combine "Paid By" and "Owed In" transactions
    // This is a computed property for the view
    var combinedTransactions: [FinancialTransaction] {
        let paid = person.toTransactions as? Set<FinancialTransaction> ?? []
        // For splits, we want the transaction the split belongs to
        let owedSplits = person.owedSplits as? Set<TransactionSplit> ?? []
        let owedTransactions = owedSplits.compactMap { $0.transaction }

        // Combine and dedup
        let all = paid.union(owedTransactions)
        return all.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
}
