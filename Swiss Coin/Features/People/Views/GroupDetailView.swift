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
    @State private var showingConversation = false

    @State private var balance: CurrencyBalance = CurrencyBalance()
    @State private var memberBalances: [(member: Person, balance: CurrencyBalance)] = []

    /// Enable settle if ANY member has a non-zero balance (not just net group total)
    private var canSettle: Bool {
        memberBalances.contains { !$0.balance.isSettled }
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
                            .font(AppTypography.displayMedium())
                            .foregroundColor(AppColors.textPrimary)

                        Text("\(group.members?.count ?? 0) Members")
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)

                        // Balance summary
                        if !balance.isSettled {
                            MultiCurrencyBalanceView(balance: balance, style: .compact)
                        }
                    }
                }
            }
        }
        .refreshable {
            await RefreshHelper.performStandardRefresh(context: viewContext)
            balance = group.calculateBalance()
            memberBalances = group.getMemberBalances()
        }
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
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionPresenter(initialGroup: group)
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
        .task {
            balance = group.calculateBalance()
            memberBalances = group.getMemberBalances()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            balance = group.calculateBalance()
            memberBalances = group.getMemberBalances()
        }
    }

    // MARK: - Group Header

    private var groupHeader: some View {
        VStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: group.colorHex ?? CurrentUser.defaultColorHex))
                .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.onAccent)
                )

            Text(group.name ?? "Unnamed Group")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)

            Text("\(group.members?.count ?? 0) Members")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)

            // Balance pill
            if !balance.isSettled {
                MultiCurrencyBalanceView(balance: balance, style: .compact)
                    .font(AppTypography.labelLarge())
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    showingAddTransaction = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: IconSize.sm))
                        Text("Add Expense")
                            .font(AppTypography.buttonDefault())
                    }
                    .foregroundColor(AppColors.buttonForeground)
                    .frame(height: ButtonHeight.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(AppButtonStyle(haptic: .none))

                Button {
                    HapticManager.tap()
                    showingConversation = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "message.fill")
                            .font(.system(size: IconSize.sm))
                        Text("Chat")
                            .font(AppTypography.buttonDefault())
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .frame(height: ButtonHeight.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
            }

            if canSettle {
                Button {
                    HapticManager.tap()
                    showingSettlement = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.sm))
                        Text("Settle Up")
                            .font(AppTypography.buttonDefault())
                    }
                    .foregroundColor(AppColors.positive)
                    .frame(height: ButtonHeight.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.positive.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
            }
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("MEMBERS")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                ForEach(Array(memberBalances.enumerated()), id: \.element.member.id) { index, item in
                    HStack(spacing: Spacing.md) {
                        Circle()
                            .fill(Color(hex: item.member.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                            .overlay(
                                Text(item.member.initials)
                                    .font(AppTypography.headingMedium())
                                    .foregroundColor(Color(hex: item.member.colorHex ?? CurrentUser.defaultColorHex))
                            )

                        Text(item.member.name ?? "Unknown")
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        MultiCurrencyBalanceView(balance: item.balance, style: .compact)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)

                    if index < memberBalances.count - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.md + Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Expenses Section

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("EXPENSES")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            if group.transactionsArray.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "doc.text")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No expenses yet")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                    Text("Add an expense to start tracking")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(group.transactionsArray.enumerated()), id: \.element) { index, transaction in
                        GroupDetailTransactionRow(transaction: transaction, group: group)

                        if index < group.transactionsArray.count - 1 {
                            Divider()
                                .padding(.leading, Spacing.lg + AvatarSize.md + Spacing.md)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
                .padding(.horizontal, Spacing.lg)
            }
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

    /// User's net position: paid - owed. Positive = others owe you.
    private var userNetAmount: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }

        if payers.count <= 1 {
            if isUserAPayer { return "You" }
            return transaction.payer?.firstName ?? "Unknown"
        }

        if isUserAPayer {
            return "You +\(payers.count - 1)"
        }
        return "\(payers.count) payers"
    }

    private var amountColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive
        } else if userNetAmount < -0.01 {
            return AppColors.negative
        }
        return AppColors.textSecondary
    }

    private var amountPrefix: String {
        guard abs(userNetAmount) > 0.01 else { return "" }
        return userNetAmount > 0 ? "+" : "-"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Direction icon
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(amountColor.opacity(0.1))
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay(
                    Image(systemName: userNetAmount > 0 ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: IconSize.sm, weight: .medium))
                        .foregroundColor(amountColor)
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(transaction.title ?? "Expense")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xxs) {
                    if let date = transaction.date {
                        Text(DateFormatter.shortDate.string(from: date))
                        Text("·")
                    }
                    Text("Paid by \(payerName)")
                }
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(amountPrefix)\(CurrencyFormatter.format(abs(userNetAmount), currencyCode: transaction.effectiveCurrency))")
                    .font(AppTypography.financialSmall())
                    .foregroundColor(amountColor)

                (Text("of ") + Text(CurrencyFormatter.format(transaction.amount, currencyCode: transaction.effectiveCurrency)).fontWeight(.bold))
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
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
