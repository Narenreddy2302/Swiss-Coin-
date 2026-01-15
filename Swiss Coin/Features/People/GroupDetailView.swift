import CoreData
import SwiftUI

struct GroupDetailView: View {
    @ObservedObject var group: UserGroup
    @State private var showingAddTransaction = false
    @State private var showingSettlement = false

    private var balance: Double {
        group.calculateBalance()
    }

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    private var memberBalances: [(member: Person, balance: Double)] {
        group.getMemberBalances()
    }

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

                        // Balance summary
                        if abs(balance) > 0.01 {
                            HStack(spacing: 4) {
                                if balance > 0 {
                                    Text("You're owed")
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.format(balance))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.positive)
                                } else {
                                    Text("You owe")
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.format(abs(balance)))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.negative)
                                }
                            }
                            .font(.subheadline)
                        }
                    }

                    // Action Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            HapticManager.buttonPress()
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
                            HapticManager.buttonPress()
                            showingSettlement = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Settle Up")
                            }
                            .frame(minWidth: 120)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(20)
                            .opacity(canSettle ? 1.0 : 0.5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!canSettle)
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, 20)
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(initialGroup: group)
            }
            .sheet(isPresented: $showingSettlement) {
                GroupSettlementView(group: group)
            }

            Section(header: Text("Members")) {
                ForEach(memberBalances, id: \.member.id) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(Text(item.member.initials).font(.caption).foregroundColor(.primary))

                        Text(item.member.name ?? "Unknown")

                        Spacer()

                        if abs(item.balance) > 0.01 {
                            if item.balance > 0 {
                                Text("owes \(CurrencyFormatter.format(item.balance))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.positive)
                            } else {
                                Text("owed \(CurrencyFormatter.format(abs(item.balance)))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.negative)
                            }
                        } else {
                            Text("settled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
        .onAppear {
            HapticManager.prepare()
        }
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
