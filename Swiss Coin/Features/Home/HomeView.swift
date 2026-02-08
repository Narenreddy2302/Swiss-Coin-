import CoreData
import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    // Fetch last 5 transactions (limited at fetch level for efficiency)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
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

    // Card overlay animation state for recent transactions
    @Namespace private var homeCardAnimation
    @State private var selectedTransaction: FinancialTransaction?

    /// Tracks the last time data was refreshed to debounce rapid refreshes
    @State private var lastRefreshDate = Date.distantPast

    // MARK: - Computed Properties

    /// Recent transactions (already limited to 5 by fetchLimit)
    private var recentTransactions: [FinancialTransaction] {
        Array(allTransactions)
    }

    /// Calculate total amount the current user owes to others
    private var totalYouOwe: Double {
        allPeople
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .compactMap { person in
                let balance = person.calculateBalance()
                return balance < 0 ? abs(balance) : nil
            }
            .reduce(0, +)
    }

    /// Calculate total amount others owe to the current user
    private var totalOwedToYou: Double {
        allPeople
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .compactMap { person in
                let balance = person.calculateBalance()
                return balance > 0 ? balance : nil
            }
            .reduce(0, +)
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
                                .font(AppTypography.title2())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.lg) {
                                    SummaryCard(
                                        title: "You Owe",
                                        amount: totalYouOwe,
                                        color: AppColors.negative,
                                        icon: "arrow.down.left.circle.fill")
                                    SummaryCard(
                                        title: "You are Owed",
                                        amount: totalOwedToYou,
                                        color: AppColors.positive,
                                        icon: "arrow.up.right.circle.fill")
                                    SummaryCard(
                                        title: "Subscriptions",
                                        amount: totalMonthlySubscriptions,
                                        color: .purple,
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
                                        .font(AppTypography.subheadlineMedium())
                                }
                                .foregroundColor(AppColors.buttonForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: ButtonHeight.md)
                                .background(AppColors.buttonBackground)
                                .cornerRadius(CornerRadius.md)
                            }
                            .buttonStyle(AppButtonStyle(haptic: .none))
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.horizontal)

                        // Recent Activity (Up Next style)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Recent Activity")
                                    .font(AppTypography.title2())
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                NavigationLink(destination: TransactionHistoryView()) {
                                    Text("See All")
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(.horizontal)

                            if recentTransactions.isEmpty {
                                EmptyStateView()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(recentTransactions, id: \.id) { transaction in
                                        TransactionRowView(
                                            transaction: transaction,
                                            animationNamespace: homeCardAnimation,
                                            selectedTransaction: $selectedTransaction
                                        )
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section + Spacing.sm)
                }
                .allowsHitTesting(selectedTransaction == nil)

                // Card modal overlay for transaction detail
                if let selected = selectedTransaction {
                    TransactionExpandedView(
                        transaction: selected,
                        animationNamespace: homeCardAnimation,
                        selectedTransaction: $selectedTransaction
                    )
                    .zIndex(2)
                    .transition(.opacity)
                }
            }
            .background(AppColors.backgroundSecondary)
            .refreshable {
                refreshData()
                HapticManager.lightTap()
            }
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
                AddTransactionView()
                    .environment(\.managedObjectContext, viewContext)
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
            }
        }
    }

    // MARK: - Refresh Helpers

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
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.accent.opacity(0.7))
                .accessibilityHidden(true)

            Text("Welcome to Swiss Coin!")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            Text("Start by adding your first expense.\nSplit bills with friends and keep track of who owes what.")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: IconSize.sm))
                Text("Tap Add Transaction to get started")
                    .font(AppTypography.subheadline())
            }
            .foregroundColor(AppColors.accent)
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.section)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(AppTypography.title2())
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                Text(CurrencyFormatter.format(amount))
                    .font(AppTypography.amountLarge())
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .frame(width: 160)
        .padding(Spacing.lg)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
        .shadow(color: AppColors.shadow, radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(CurrencyFormatter.format(amount))")
    }
}

