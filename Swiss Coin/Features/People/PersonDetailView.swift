import CoreData
import os
import SwiftUI

struct PersonDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var person: Person
    @State private var showingAddTransaction = false
    @State private var showingConversation = false
    @State private var showingEditPerson = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSettlement = false

    private var balance: Double {
        person.calculateBalance()
    }

    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            return "\(person.firstName) owes you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(person.firstName) \(formatted)"
        } else {
            return "Settled up"
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    var body: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .center, spacing: Spacing.lg) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                        .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                        .overlay(
                            Text(person.initials)
                                .font(AppTypography.largeTitle())
                                .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                        )

                    VStack(spacing: Spacing.xs) {
                        Text(person.name ?? "Unknown")
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)

                        if let phone = person.phoneNumber, !phone.isEmpty {
                            Text(phone)
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Text(balanceText)
                            .font(AppTypography.headline())
                            .foregroundColor(balanceColor)
                            .padding(.top, Spacing.sm)
                    }

                    // Action Buttons
                    HStack(spacing: Spacing.md) {
                        Button(action: {
                            HapticManager.tap()
                            showingAddTransaction = true
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: IconSize.sm))
                                Text("Add Expense")
                                    .font(AppTypography.subheadlineMedium())
                            }
                            .foregroundColor(AppColors.buttonForeground)
                            .frame(height: ButtonHeight.md)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }

                        Button(action: {
                            HapticManager.tap()
                            showingConversation = true
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: IconSize.sm))
                                Text("Chat")
                                    .font(AppTypography.subheadlineMedium())
                            }
                            .foregroundColor(AppColors.textPrimary)
                            .frame(height: ButtonHeight.md)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }
                    }

                    // Settle Button (shown when there's an outstanding balance)
                    if canSettle {
                        Button(action: {
                            HapticManager.tap()
                            showingSettlement = true
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: IconSize.sm))
                                Text("Settle Up")
                                    .font(AppTypography.subheadlineMedium())
                            }
                            .foregroundColor(AppColors.positive)
                            .frame(height: ButtonHeight.md)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.positive.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }
                    }

                    Spacer().frame(height: Spacing.sm)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, Spacing.lg)
            }
            .sheet(isPresented: $showingAddTransaction) {
                QuickActionSheetPresenter(initialPerson: person)
            }
            .sheet(isPresented: $showingConversation) {
                NavigationStack {
                    PersonConversationView(person: person)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingConversation = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingSettlement) {
                SettlementView(person: person, currentBalance: balance)
            }

            // Transactions List
            Section {
                if combinedTransactions.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.system(size: IconSize.xl))
                            .foregroundColor(AppColors.textSecondary)
                        Text("No transactions yet")
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                        Text("Add an expense to start tracking balances")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(combinedTransactions) { transaction in
                        PersonDetailTransactionRow(transaction: transaction, person: person)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AppColors.backgroundSecondary)
                    }
                }
            } header: {
                if !combinedTransactions.isEmpty {
                    Text("Recent Activity")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(person.name ?? "Person")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        HapticManager.tap()
                        showingEditPerson = true
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
        .sheet(isPresented: $showingEditPerson) {
            NavigationStack {
                EditPersonView(person: person)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .alert("Delete Person", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePerson()
            }
        } message: {
            Text("This will permanently delete \(person.name ?? "this person") and ALL their transactions, payment history, and shared expenses. Other people's balances will be affected. This action cannot be undone.")
        }
    }

    private func deletePerson() {
        viewContext.delete(person)
        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to delete person: \(error.localizedDescription)")
        }
    }

    /// Get only mutual transactions (where both you and this person are involved)
    /// sorted by most recent first, limited to 10 for detail view performance.
    private var combinedTransactions: [FinancialTransaction] {
        return Array(person.getMutualTransactions().prefix(10))
    }
}

struct PersonDetailTransactionRow: View {
    let transaction: FinancialTransaction
    let person: Person
    @Environment(\.managedObjectContext) private var viewContext

    private var isUserPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var isPersonPayer: Bool {
        transaction.payer?.id == person.id
    }

    /// Calculate the display amount from the current user's perspective
    private var userPerspectiveAmount: Double {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        if isUserPayer {
            // User paid - show what this person owes you
            if let theirSplit = splits.first(where: { $0.owedBy?.id == person.id }) {
                return theirSplit.amount
            }
            return 0
        } else if isPersonPayer {
            // This person paid - show what you owe them
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
            return 0
        } else {
            // Third party paid - show your share
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
            return 0
        }
    }

    private var amountColor: Color {
        if isUserPayer && userPerspectiveAmount > 0 {
            return AppColors.positive // They owe you
        } else if !isUserPayer && userPerspectiveAmount > 0 {
            return AppColors.negative // You owe them
        }
        return AppColors.textSecondary
    }

    private var amountPrefix: String {
        if isUserPayer && userPerspectiveAmount > 0 {
            return "+"
        }
        return ""
    }

    private var statusText: String {
        if isUserPayer {
            return "You paid"
        } else if isPersonPayer {
            return "\(person.firstName) paid"
        } else {
            return "Paid by \(transaction.payer?.firstName ?? "someone")"
        }
    }

    private var statusColor: Color {
        if isUserPayer {
            return AppColors.positive
        }
        return AppColors.negative
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

                Text(statusText)
                    .font(AppTypography.caption())
                    .foregroundColor(statusColor)
            }

            Spacer()

            Text("\(amountPrefix)\(CurrencyFormatter.format(userPerspectiveAmount))")
                .font(AppTypography.amountSmall())
                .foregroundColor(amountColor)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
    }
}
