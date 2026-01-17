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
                VStack(alignment: .center, spacing: Spacing.lg) {
                    Circle()
                        .fill(Color(hex: group.colorHex ?? "#007AFF"))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 10)

                    VStack(spacing: Spacing.xs) {
                        Text(group.displayName)
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)

                        Text("\(group.members?.count ?? 0) Members")
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)

                        // Balance summary
                        if abs(balance) > 0.01 {
                            HStack(spacing: Spacing.xs) {
                                if balance > 0 {
                                    Text("You're owed")
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(CurrencyFormatter.format(balance))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.positive)
                                } else {
                                    Text("You owe")
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(CurrencyFormatter.format(abs(balance)))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.negative)
                                }
                            }
                            .font(AppTypography.subheadline())
                        }
                    }

                    // Action Buttons
                    HStack(spacing: Spacing.lg) {
                        Button(action: {
                            HapticManager.buttonPress()
                            showingAddTransaction = true
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Expense")
                            }
                            .font(AppTypography.subheadlineMedium())
                            .frame(minWidth: 120)
                            .padding(.vertical, Spacing.sm)
                            .background(AppColors.backgroundTertiary)
                            .cornerRadius(CornerRadius.lg)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            HapticManager.buttonPress()
                            showingSettlement = true
                        }) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Settle Up")
                            }
                            .font(AppTypography.subheadlineMedium())
                            .frame(minWidth: 120)
                            .padding(.vertical, Spacing.sm)
                            .background(AppColors.backgroundTertiary)
                            .cornerRadius(CornerRadius.lg)
                            .opacity(canSettle ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSettle)
                    }
                    .padding(.bottom, Spacing.sm)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, Spacing.xl)
            }
            .sheet(isPresented: $showingAddTransaction) {
                QuickActionSheetPresenter(initialGroup: group)
            }
            .sheet(isPresented: $showingSettlement) {
                GroupSettlementView(group: group)
            }

            Section(header: Text("Members").font(AppTypography.subheadlineMedium())) {
                ForEach(memberBalances, id: \.member.id) { item in
                    HStack(spacing: Spacing.md) {
                        Circle()
                            .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay(
                                Text(item.member.initials)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textPrimary)
                            )

                        Text(item.member.displayName)
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        if abs(item.balance) > 0.01 {
                            if item.balance > 0 {
                                Text("owes \(CurrencyFormatter.format(item.balance))")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.positive)
                            } else {
                                Text("owed \(CurrencyFormatter.format(abs(item.balance)))")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.negative)
                            }
                        } else {
                            Text("settled")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }

            Section(header: Text("Expenses").font(AppTypography.subheadlineMedium())) {
                if group.transactionsArray.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "receipt")
                                .font(.system(size: IconSize.lg))
                                .foregroundColor(AppColors.textSecondary)
                            Text("No expenses yet")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, Spacing.xl)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(group.transactionsArray, id: \.self) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
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
