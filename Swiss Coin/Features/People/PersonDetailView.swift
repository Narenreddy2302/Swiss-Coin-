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

    // MARK: - Computed Properties

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
            return "All settled up"
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

    /// Mutual transactions sorted by most recent first, capped at 10 for performance.
    private var combinedTransactions: [FinancialTransaction] {
        return Array(person.getMutualTransactions().prefix(10))
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
            Text(balanceText)
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
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !combinedTransactions.isEmpty {
                Text("RECENT ACTIVITY")
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(combinedTransactions) { transaction in
                        PersonDetailTransactionRow(transaction: transaction, person: person)

                        if transaction.objectID != combinedTransactions.last?.objectID {
                            Divider()
                                .padding(.leading, Spacing.lg + AvatarSize.md + Spacing.md)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(AppColors.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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

// MARK: - Transaction Row

struct PersonDetailTransactionRow: View {
    let transaction: FinancialTransaction
    let person: Person

    // MARK: - Computed Properties

    /// Net balance for this transaction: positive = person owes you
    private var pairwiseResult: Double {
        guard let currentUserId = CurrentUser.currentUserId,
              let personId = person.id else { return 0 }
        return transaction.pairwiseBalance(personA: currentUserId, personB: personId)
    }

    private var isUserNetCreditor: Bool {
        pairwiseResult > 0
    }

    /// The split amount relevant to this transaction (always positive).
    /// Direction is determined by who paid.
    private var userPerspectiveAmount: Double {
        abs(pairwiseResult)
    }

    private var amountColor: Color {
        if isUserNetCreditor && userPerspectiveAmount > 0 {
            return AppColors.positive
        } else if !isUserNetCreditor && userPerspectiveAmount > 0 {
            return AppColors.negative
        }
        return AppColors.textSecondary
    }

    private var amountPrefix: String {
        if isUserNetCreditor && userPerspectiveAmount > 0 {
            return "+"
        }
        return ""
    }

    private var statusText: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        let isPersonAPayer = payers.contains { $0.personId == person.id }

        if payers.count > 1 {
            if isUserAPayer && isPersonAPayer {
                return "You & \(person.firstName) paid"
            } else if isUserAPayer {
                return "You +\(payers.count - 1) paid"
            }
            return "\(payers.count) payers"
        }

        if isUserAPayer {
            return "You paid"
        } else if isPersonAPayer {
            return "\(person.firstName) paid"
        } else {
            return "Paid by \(transaction.payer?.firstName ?? "someone")"
        }
    }

    private var statusColor: Color {
        if isUserNetCreditor {
            return AppColors.positive
        }
        return AppColors.negative
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Direction icon
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(amountColor.opacity(0.1))
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay(
                    Image(systemName: isUserNetCreditor ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundColor(amountColor)
                )

            // Title and metadata
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xxs) {
                    if let date = transaction.date {
                        Text(DateFormatter.shortDate.string(from: date))
                        Text("·")
                    }
                    Text(statusText)
                }
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Amount
            Text("\(amountPrefix)\(CurrencyFormatter.format(userPerspectiveAmount))")
                .font(AppTypography.amountSmall())
                .foregroundColor(amountColor)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title ?? "Expense"), \(amountPrefix)\(CurrencyFormatter.format(userPerspectiveAmount)), \(statusText)")
    }
}
