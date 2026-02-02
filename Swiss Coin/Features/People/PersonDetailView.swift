import CoreData
import SwiftUI

struct PersonDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var person: Person
    @State private var showingAddTransaction = false
    @State private var showingConversation = false
    @State private var showingEditPerson = false
    @State private var showingDeleteConfirmation = false
    
    private var balance: Double {
        person.calculateBalance()
    }
    
    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            return "\(person.name ?? "They") owe you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(formatted)"
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
                            .foregroundColor(.white)
                            .frame(height: ButtonHeight.md)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.accent)
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
                            .foregroundColor(AppColors.accent)
                            .frame(height: ButtonHeight.md)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }
                    }
                    .padding(.bottom, Spacing.sm)
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
            Text("Are you sure you want to delete \(person.name ?? "this person")? This will remove all associated data.")
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
            print("Error deleting person: \(error)")
        }
    }

    // Helper to combine "Paid By" and "Owed In" transactions
    private var combinedTransactions: [FinancialTransaction] {
        let paid = person.toTransactions as? Set<FinancialTransaction> ?? []
        // For splits, we want the transaction the split belongs to
        let owedSplits = person.owedSplits as? Set<TransactionSplit> ?? []
        let owedTransactions = owedSplits.compactMap { $0.transaction }

        // Combine and dedup
        let all = paid.union(owedTransactions)
        return Array(all)
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
            .prefix(10) // Show only recent 10 transactions
            .map { $0 }
    }
}

struct PersonDetailTransactionRow: View {
    let transaction: FinancialTransaction
    let person: Person
    @Environment(\.managedObjectContext) private var viewContext
    
    private var amountForPerson: Double {
        if transaction.payer?.id == person.id {
            // This person paid, show positive (they're owed)
            return transaction.amount
        } else {
            // Find the split for this person
            if let splits = transaction.splits as? Set<TransactionSplit>,
               let personSplit = splits.first(where: { $0.owedBy?.id == person.id }) {
                return personSplit.amount
            }
        }
        return 0.0
    }
    
    private var amountColor: Color {
        if transaction.payer?.id == person.id {
            return AppColors.positive // They paid, so they're owed
        } else {
            return AppColors.negative // They owe for their split
        }
    }
    
    private var amountPrefix: String {
        if transaction.payer?.id == person.id {
            return "+" // They paid
        } else {
            return "-" // They owe
        }
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
                
                if transaction.payer?.id == person.id {
                    Text("They paid")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.positive)
                } else {
                    Text("Their share")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.negative)
                }
            }
            
            Spacer()
            
            Text("\(amountPrefix)\(CurrencyFormatter.format(amountForPerson))")
                .font(AppTypography.amountSmall())
                .foregroundColor(amountColor)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
    }
}
