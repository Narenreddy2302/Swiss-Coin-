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
    @State private var selectedTransaction: FinancialTransaction?

    // MARK: - Cached Data (computed asynchronously to avoid blocking main thread)

    @State private var balance: Double = 0
    @State private var combinedTransactions: [FinancialTransaction] = []

    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            return "\(person.firstName) owes you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(person.firstName) \(formatted)"
        } else {
            return "All settled up"
        }
    }

    private var balanceTextView: Text {
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            return Text("\(person.firstName) owes you ") + Text(formatted).fontWeight(.bold)
        } else if balance < -0.01 {
            return Text("You owe \(person.firstName) ") + Text(formatted).fontWeight(.bold)
        } else {
            return Text("All settled up")
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

    private var balanceBackgroundColor: Color {
        if balance > 0.01 {
            return AppColors.positive.opacity(0.1)
        } else if balance < -0.01 {
            return AppColors.negative.opacity(0.1)
        } else {
            return AppColors.backgroundTertiary
        }
    }

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                actionButtons
                    .padding(.top, Spacing.lg)
                    .padding(.horizontal, Spacing.lg)

                recentActivitySection
                    .padding(.top, Spacing.xl)
            }
            .padding(.bottom, Spacing.section)
        }
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

                    Button {
                        HapticManager.tap()
                        archivePerson()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
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
        .sheet(isPresented: Binding(
            get: { selectedTransaction != nil },
            set: { if !$0 { selectedTransaction = nil } }
        )) {
            if let transaction = selectedTransaction {
                NavigationStack {
                    TransactionDetailView(transaction: transaction)
                }
                .environment(\.managedObjectContext, viewContext)
            }
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
        .task {
            loadPersonDetailData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            loadPersonDetailData()
        }
    }

    /// Recompute balance and transactions outside of body evaluation.
    private func loadPersonDetailData() {
        balance = person.calculateBalance()
        combinedTransactions = Array(person.getMutualTransactions().prefix(10))
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.md) {
            // Solid filled avatar
            Circle()
                .fill(Color(hex: person.colorHex ?? AppColors.defaultAvatarColorHex))
                .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.largeTitle())
                        .foregroundColor(.white)
                )

            // Name
            Text(person.name ?? "Unknown")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            // Phone number
            if let phone = person.phoneNumber, !phone.isEmpty {
                Text(phone)
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }

            // Balance pill
            balanceTextView
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(balanceColor)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(balanceBackgroundColor)
                )
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Add Expense
                Button {
                    HapticManager.tap()
                    showingAddTransaction = true
                } label: {
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

                // Chat
                Button {
                    HapticManager.tap()
                    showingConversation = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "message.fill")
                            .font(.system(size: IconSize.sm))
                        Text("Chat")
                            .font(AppTypography.subheadlineMedium())
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .frame(height: ButtonHeight.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }

            // Settle Up (only shown when there is an outstanding balance)
            if canSettle {
                Button {
                    HapticManager.tap()
                    showingSettlement = true
                } label: {
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
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !combinedTransactions.isEmpty {
                // Section header matching TransactionHistoryView style
                HStack {
                    Text("Recent Activity")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text("\(combinedTransactions.count)")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(AppColors.backgroundTertiary)
                        )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)

                // Transaction rows matching TransactionHistoryView card style
                VStack(spacing: 0) {
                    ForEach(combinedTransactions) { transaction in
                        TransactionRowView(
                            transaction: transaction,
                            onDelete: nil,
                            selectedTransaction: $selectedTransaction
                        )

                        if transaction.objectID != combinedTransactions.last?.objectID {
                            Divider()
                                .padding(.leading, Spacing.lg)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, Spacing.lg)
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "doc.text")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No transactions yet")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Text("Add an expense to start tracking")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
            }
        }
    }

    // MARK: - Actions

    private func archivePerson() {
        person.isArchived = true
        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to archive person: \(error.localizedDescription)")
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
}

