import CoreData
import os
import SwiftUI

struct GroupDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var group: UserGroup
    @State private var showingAddTransaction = false
    @State private var showingSettlement = false
    @State private var showingEditGroup = false
    @State private var showingDeleteConfirmation = false

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
                        .fill(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                        .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: IconSize.xl))
                                .foregroundColor(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex))
                        )

                    VStack(spacing: Spacing.xs) {
                        Text(group.name ?? "Unnamed Group")
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
                            HapticManager.tap()
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
                            HapticManager.tap()
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
                            .fill(Color(hex: item.member.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .overlay(
                                Text(item.member.initials)
                                    .font(AppTypography.caption())
                                    .foregroundColor(Color(hex: item.member.colorHex ?? CurrentUser.defaultColorHex))
                            )

                        Text(item.member.name ?? "Unknown")
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
                        GroupDetailTransactionRow(transaction: transaction, group: group)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AppColors.backgroundSecondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        HapticManager.tap()
                        showingEditGroup = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        HapticManager.tap()
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: IconSize.md))
                }
            }
        }
        .sheet(isPresented: $showingEditGroup) {
            NavigationStack {
                EditGroupView(group: group)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("Are you sure you want to delete \"\(group.name ?? "this group")\"? This will remove the group and its data.")
        }
        .onAppear {
            HapticManager.prepare()
        }
    }

    private func deleteGroup() {
        viewContext.delete(group)
        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to delete group: \(error.localizedDescription)")
        }
    }
}

struct GroupDetailTransactionRow: View {
    let transaction: FinancialTransaction
    let group: UserGroup
    @Environment(\.managedObjectContext) private var viewContext
    
    private var currentUserBalance: Double {
        group.calculateBalanceWith(member: CurrentUser.getOrCreate(in: viewContext))
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                
                if let date = transaction.date {
                    Text(DateFormatter.shortDate.string(from: date))
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                
                if let paidBy = transaction.payer {
                    Text("Paid by \(paidBy.name ?? "Unknown")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            Text(CurrencyFormatter.format(transaction.amount))
                .font(AppTypography.amountSmall())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
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
