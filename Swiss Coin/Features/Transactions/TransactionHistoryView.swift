import CoreData
import os
import SwiftUI

// MARK: - Filter Model

enum TransactionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case youOwe = "You Owe"
    case owedToYou = "Owed to You"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .youOwe: return "arrow.up.right"
        case .owedToYou: return "arrow.down.left"
        }
    }
}

// MARK: - Date Section Model

private struct DateSection: Identifiable {
    let id: String
    let title: String
    let transactions: [FinancialTransaction]
}

struct TransactionHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var transactions: FetchedResults<FinancialTransaction>

    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: FinancialTransaction?
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    @State private var showingSearch = false

    // MARK: - Filtered Transactions

    private var filteredTransactions: [FinancialTransaction] {
        var result = Array(transactions)

        // Apply text search
        if !searchText.isEmpty {
            result = result.filter { transaction in
                let title = transaction.title ?? ""
                let payerName = transaction.payer?.displayName ?? ""
                let amount = CurrencyFormatter.format(transaction.amount)
                let searchLower = searchText.lowercased()
                return title.lowercased().contains(searchLower)
                    || payerName.lowercased().contains(searchLower)
                    || amount.lowercased().contains(searchLower)
            }
        }

        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .youOwe:
            result = result.filter { transaction in
                !CurrentUser.isCurrentUser(transaction.payer?.id) && userShare(for: transaction) > 0.01
            }
        case .owedToYou:
            result = result.filter { transaction in
                CurrentUser.isCurrentUser(transaction.payer?.id) && othersOwe(for: transaction) > 0.01
            }
        }

        return result
    }

    // MARK: - Date-Grouped Sections

    private var groupedSections: [DateSection] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday

        var groups: [String: [FinancialTransaction]] = [:]
        var groupOrder: [String] = []

        for transaction in filteredTransactions {
            let date = transaction.date ?? Date.distantPast
            let key: String

            if calendar.isDate(date, inSameDayAs: now) {
                key = "Today"
            } else if calendar.isDate(date, inSameDayAs: startOfYesterday) {
                key = "Yesterday"
            } else if date >= startOfWeek {
                key = "This Week"
            } else if date >= startOfMonth {
                key = "This Month"
            } else {
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMMM yyyy"
                key = monthFormatter.string(from: date)
            }

            if groups[key] == nil {
                groups[key] = []
                groupOrder.append(key)
            }
            groups[key]?.append(transaction)
        }

        return groupOrder.compactMap { key in
            guard let txns = groups[key] else { return nil }
            return DateSection(id: key, title: key, transactions: txns)
        }
    }

    // MARK: - Summary Stats

    private var totalYouOwe: Double {
        transactions.reduce(0.0) { sum, transaction in
            if !CurrentUser.isCurrentUser(transaction.payer?.id) {
                return sum + userShare(for: transaction)
            }
            return sum
        }
    }

    private var totalOwedToYou: Double {
        transactions.reduce(0.0) { sum, transaction in
            if CurrentUser.isCurrentUser(transaction.payer?.id) {
                return sum + othersOwe(for: transaction)
            }
            return sum
        }
    }

    private var transactionCount: Int {
        filteredTransactions.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                if transactions.isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent
                }

                // FAB overlay
                FinanceQuickActionView()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !transactions.isEmpty {
                        Button {
                            HapticManager.lightTap()
                            withAnimation(AppAnimation.standard) {
                                showingSearch.toggle()
                                if !showingSearch {
                                    searchText = ""
                                }
                            }
                        } label: {
                            Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: IconSize.md, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
            }
            .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    transactionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let transaction = transactionToDelete {
                        deleteTransaction(transaction)
                    }
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            // Header section (search, filters, summary)
            Section {
                VStack(spacing: 0) {
                    if showingSearch {
                        searchBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.bottom, Spacing.sm)
                    }

                    filterBar
                        .padding(.bottom, Spacing.md)

                    summaryStrip

                    if !searchText.isEmpty || selectedFilter != .all {
                        resultsHeader
                            .padding(.top, Spacing.md)
                            .transition(.opacity)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Transaction sections or empty state
            if filteredTransactions.isEmpty {
                Section {
                    noResultsView
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedSections) { section in
                    Section {
                        ForEach(section.transactions, id: \.objectID) { transaction in
                            TransactionRowView(
                                transaction: transaction,
                                onEdit: nil,
                                onDelete: {
                                    transactionToDelete = transaction
                                    showingDeleteAlert = true
                                }
                            )
                            .listRowInsets(EdgeInsets())
                        }
                    } header: {
                        Text(section.title)
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(nil)
                    }
                }
            }

            // Bottom spacing for FAB
            Section {
                Spacer()
                    .frame(height: 80)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .refreshable {
            viewContext.refreshAllObjects()
            HapticManager.lightTap()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.textTertiary)

            TextField("Search transactions...", text: $searchText)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    HapticManager.lightTap()
                    withAnimation(AppAnimation.quick) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(TransactionFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.systemImage,
                        isSelected: selectedFilter == filter
                    ) {
                        HapticManager.selectionChanged()
                        withAnimation(AppAnimation.standard) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            // You Owe
            VStack(spacing: Spacing.xxs) {
                Text("You Owe")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                Text(CurrencyFormatter.format(totalYouOwe))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(totalYouOwe > 0.01 ? AppColors.negative : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(AppColors.separator)
                .frame(width: 1, height: 32)

            // Owed to You
            VStack(spacing: Spacing.xxs) {
                Text("Owed to You")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                Text(CurrencyFormatter.format(totalOwedToYou))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(totalOwedToYou > 0.01 ? AppColors.positive : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(AppColors.separator)
                .frame(width: 1, height: 32)

            // Net Balance
            VStack(spacing: Spacing.xxs) {
                Text("Net")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                let net = totalOwedToYou - totalYouOwe
                Text(CurrencyFormatter.formatWithSign(net))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(net > 0.01 ? AppColors.positive : net < -0.01 ? AppColors.negative : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Results Header

    private var resultsHeader: some View {
        HStack {
            let count = filteredTransactions.count
            Text("\(count) \(count == 1 ? "transaction" : "transactions") found")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            Spacer()

            if searchText.isEmpty && selectedFilter != .all {
                Button {
                    HapticManager.lightTap()
                    withAnimation(AppAnimation.standard) {
                        selectedFilter = .all
                    }
                } label: {
                    Text("Clear Filter")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Animated icon composition
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.accent.opacity(0.8))
            }

            VStack(spacing: Spacing.sm) {
                Text("No Transactions Yet")
                    .font(AppTypography.title2())
                    .foregroundColor(AppColors.textPrimary)

                Text("Your transaction history will appear here\nonce you start splitting expenses.")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Hint
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: IconSize.md))
                Text("Tap the + button to get started")
                    .font(AppTypography.subheadlineMedium())
            }
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(AppColors.accent.opacity(0.08))
            .cornerRadius(CornerRadius.lg)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.xl))
                .foregroundColor(AppColors.textTertiary)

            Text("No matches found")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Try adjusting your search or filter\nto find what you're looking for.")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            if selectedFilter != .all || !searchText.isEmpty {
                Button {
                    HapticManager.lightTap()
                    withAnimation(AppAnimation.standard) {
                        searchText = ""
                        selectedFilter = .all
                    }
                } label: {
                    Text("Reset Filters")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.buttonForeground)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(AppColors.buttonBackground)
                        .cornerRadius(CornerRadius.md)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(.vertical, Spacing.section * 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func userShare(for transaction: FinancialTransaction) -> Double {
        guard let splits = transaction.splits?.allObjects as? [TransactionSplit] else { return 0 }
        return splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) })?.amount ?? 0
    }

    private func othersOwe(for transaction: FinancialTransaction) -> Double {
        let myShare = userShare(for: transaction)
        return max(transaction.amount - myShare, 0)
    }

    // MARK: - Delete Logic

    private func deleteTransaction(_ transaction: FinancialTransaction) {
        withAnimation(AppAnimation.standard) {
            if let splits = transaction.splits as? Set<TransactionSplit> {
                splits.forEach { viewContext.delete($0) }
            }
            viewContext.delete(transaction)

            do {
                try viewContext.save()
                HapticManager.success()
            } catch {
                viewContext.rollback()
                HapticManager.error()
                AppLogger.transactions.error("Failed to delete transaction: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Filter Chip Component

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.xs, weight: .medium))
                Text(title)
                    .font(AppTypography.subheadlineMedium())
            }
            .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.buttonBackground : AppColors.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(AppButtonStyle(haptic: .none))
    }
}
