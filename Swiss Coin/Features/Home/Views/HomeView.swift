import CoreData
import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    // Fetch last 5 valid transactions (filter out deleted/corrupt entries)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "title != nil AND title.length > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
        request.fetchLimit = 5
        return request
    }(), animation: .default)
    private var allTransactions: FetchedResults<FinancialTransaction>

    // Fetch all people to calculate balances (with batch size for memory efficiency)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var allPeople: FetchedResults<Person>

    // Fetch active subscriptions for monthly cost summary
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.name, ascending: true)]
        return request
    }(), animation: .default)
    private var activeSubscriptions: FetchedResults<Subscription>

    @State private var showingProfile = false
    @State private var showingAddTransaction = false

    @State private var selectedTransaction: FinancialTransaction?

    /// Tracks the last time data was refreshed to debounce rapid refreshes
    @State private var lastRefreshDate = Date.distantPast
    @State private var isRefreshing = false
    @State private var balanceRecalcTask: Task<Void, Never>?

    /// Cached balance totals computed asynchronously to avoid blocking the main thread
    @State private var cachedYouOwe: [(code: String, amount: Double)] = []
    @State private var cachedOwedToYou: [(code: String, amount: Double)] = []

    // MARK: - Computed Properties

    /// Recent transactions (already limited to 5 by fetchLimit, filtered for validity)
    private var recentTransactions: [FinancialTransaction] {
        Array(allTransactions).filter { !$0.isDeleted && $0.managedObjectContext != nil }
    }

    /// Calculate total monthly cost of all active subscriptions
    private var totalMonthlySubscriptions: Double {
        activeSubscriptions
            .map { $0.monthlyEquivalent }
            .reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        // Summary Section (Hero-like)
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Summary")
                                .font(AppTypography.displayMedium())
                                .tracking(AppTypography.Tracking.displayMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.lg) {
                                    SummaryCard(
                                        title: "You Owe",
                                        amounts: cachedYouOwe,
                                        color: AppColors.negative,
                                        icon: "arrow.down.left.circle.fill")
                                    SummaryCard(
                                        title: "You are Owed",
                                        amounts: cachedOwedToYou,
                                        color: AppColors.positive,
                                        icon: "arrow.up.right.circle.fill")
                                    SummaryCard(
                                        title: "Subscriptions",
                                        amounts: [],
                                        singleAmount: totalMonthlySubscriptions,
                                        color: AppColors.assetRealEstate,
                                        icon: "repeat.circle.fill")
                                }
                                .padding(.horizontal)
                            }

                            // Add Transaction button
                            Button {
                                HapticManager.tap()
                                showingAddTransaction = true
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: IconSize.sm))
                                        .accessibilityHidden(true)
                                    Text("Add Transaction")
                                        .font(AppTypography.buttonDefault())
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.horizontal)

                        // Recent Activity (Up Next style)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Recent Activity")
                                    .font(AppTypography.displayMedium())
                                    .tracking(AppTypography.Tracking.displayMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                NavigationLink(destination: TransactionHistoryView()) {
                                    Text("See All")
                                        .font(AppTypography.labelLarge())
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(recentTransactions, id: \.id) { transaction in
                                    TransactionRowView(
                                        transaction: transaction,
                                        selectedTransaction: $selectedTransaction
                                    )
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section + Spacing.sm)
                }
                .allowsHitTesting(selectedTransaction == nil)

            }
            .background(AppColors.backgroundSecondary)
            .refreshable { await performRefresh() }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton {
                        showingProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionPresenter()
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
            .task {
                await recalculateBalances()
            }
            .onAppear {
                refreshIfStale()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshIfStale()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            ) { _ in
                refreshIfStale()
                balanceRecalcTask?.cancel()
                balanceRecalcTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    await recalculateBalances()
                }
            }
        }
    }

    // MARK: - Refresh Helpers

    private func performRefresh() async {
        isRefreshing = true
        refreshData()
        await recalculateBalances()
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRefreshing = false
        HapticManager.lightTap()
    }

    /// Refresh only if enough time has elapsed since the last refresh (debounce).
    /// Prevents redundant refreshes when multiple triggers fire in quick succession
    /// (e.g., tab switch + save notification arriving simultaneously).
    private func refreshIfStale() {
        guard Date().timeIntervalSince(lastRefreshDate) > 0.5 else { return }
        refreshData()
    }

    /// Invalidate all faulted CoreData objects so @FetchRequest results and
    /// relationship-dependent computed properties (balances) reflect the latest
    /// persistent store state.
    private func refreshData() {
        viewContext.refreshAllObjects()
        lastRefreshDate = Date()
    }

    /// Compute balance totals on a background Core Data context to avoid blocking the main thread.
    private func recalculateBalances() async {
        let container = PersistenceController.shared.container
        let backgroundContext = container.newBackgroundContext()

        let result: (owe: [(code: String, amount: Double)], owed: [(code: String, amount: Double)]) = await backgroundContext.perform {
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
            let people = (try? backgroundContext.fetch(fetchRequest)) ?? []

            var oweByCurrency: [String: Double] = [:]
            var owedByCurrency: [String: Double] = [:]

            for person in people {
                guard !CurrentUser.isCurrentUser(person.id) else { continue }
                let balance = person.calculateBalance()
                for (code, amount) in balance.nonZero {
                    if amount < 0 {
                        oweByCurrency[code, default: 0] += abs(amount)
                    } else if amount > 0 {
                        owedByCurrency[code, default: 0] += amount
                    }
                }
            }

            let sortedOwe = oweByCurrency.map { (code: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }
            let sortedOwed = owedByCurrency.map { (code: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }

            return (sortedOwe, sortedOwed)
        }

        await MainActor.run {
            cachedYouOwe = result.owe
            cachedOwedToYou = result.owed
        }
    }
}


struct SummaryCard: View {
    let title: String
    let amounts: [(code: String, amount: Double)]
    var singleAmount: Double? = nil
    let color: Color
    let icon: String

    private var displayAmount: Double {
        if let single = singleAmount { return single }
        return amounts.first?.amount ?? 0
    }

    private var accessibilityText: String {
        if let single = singleAmount {
            return "\(title): \(CurrencyFormatter.format(single))"
        }
        if amounts.isEmpty {
            return "\(title): \(CurrencyFormatter.format(0))"
        }
        let parts = amounts.map { CurrencyFormatter.format($0.amount, currencyCode: $0.code) }
        return "\(title): \(parts.joined(separator: ", "))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(AppTypography.displayMedium())
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textSecondary)

                if let single = singleAmount {
                    Text(CurrencyFormatter.format(single))
                        .font(AppTypography.financialLarge())
                        .tracking(AppTypography.Tracking.financialLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(AppAnimation.standard, value: single)
                } else if amounts.isEmpty {
                    Text(CurrencyFormatter.format(0))
                        .font(AppTypography.financialLarge())
                        .tracking(AppTypography.Tracking.financialLarge)
                        .foregroundColor(AppColors.textPrimary)
                } else if amounts.count == 1 {
                    let entry = amounts[0]
                    Text(CurrencyFormatter.format(entry.amount, currencyCode: entry.code))
                        .font(AppTypography.financialLarge())
                        .tracking(AppTypography.Tracking.financialLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(AppAnimation.standard, value: entry.amount)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        ForEach(amounts, id: \.code) { entry in
                            HStack(spacing: Spacing.xs) {
                                Text(CurrencyFormatter.flag(for: entry.code))
                                    .font(.system(size: 12))
                                Text(CurrencyFormatter.format(entry.amount, currencyCode: entry.code))
                                    .font(AppTypography.financialDefault())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 160)
        .padding(Spacing.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
}

