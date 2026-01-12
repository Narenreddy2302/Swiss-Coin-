import CoreData
import SwiftUI

struct GroupDetailView: View {
    @ObservedObject var group: UserGroup
    @State private var showingAddTransaction = false

    var body: some View {
        List {
            // Group Header
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Circle()
                        .fill(Color(hex: group.colorHex ?? "#007AFF"))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 10)

                    VStack(spacing: 4) {
                        Text(group.name ?? "Unknown Group")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(group.members?.count ?? 0) Members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Action Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            showingAddTransaction = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Expense")
                            }
                            .frame(minWidth: 120)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            // Placeholder for future Settle Up logic
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Settle Up")
                            }
                            .frame(minWidth: 120)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(20)
                            .opacity(0.5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(true)
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, 20)
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }

            Section(header: Text("Members")) {
                ForEach(group.membersArray, id: \.self) { person in
                    HStack {
                        Circle()
                            .fill(Color(hex: person.colorHex ?? "#808080").opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(Text(person.initials).font(.caption).foregroundColor(.primary))

                        Text(person.name ?? "Unknown")
                    }
                }
            }

            Section(header: Text("Expenses")) {
                if group.transactionsArray.isEmpty {
                    Text("No expenses yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(group.transactionsArray, id: \.self) { transaction in
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
}

// Helpers for relationships to Arrays
extension UserGroup {
    var membersArray: [Person] {
        let set = members as? Set<Person> ?? []
        return set.sorted { $0.name ?? "" < $1.name ?? "" }
    }

    var transactionsArray: [FinancialTransaction] {
        let set = transactions as? Set<FinancialTransaction> ?? []
        return set.sorted { $0.date ?? Date() > $1.date ?? Date() }
    }
}
