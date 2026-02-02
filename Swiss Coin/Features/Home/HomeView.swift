import CoreData
import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch last 5 transactions (limited at fetch level for efficiency)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)],
        fetchLimit: 5,
        animation: .default)
    private var allTransactions: FetchedResults<FinancialTransaction>

    // Fetch all people to calculate balances
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var allPeople: FetchedResults<Person>

    @State private var showingProfile = false
    @State private var showingSettleSheet = false

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
                                }
                                .padding(.horizontal)
                            }

                            // Quick Settle button
                            if totalYouOwe > 0.01 {
                                Button {
                                    HapticManager.tap()
                                    showingSettleSheet = true
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: IconSize.sm))
                                            .accessibilityHidden(true)
                                        Text("Settle Up")
                                            .font(AppTypography.subheadlineMedium())
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: ButtonHeight.md)
                                    .background(AppColors.positive)
                                    .cornerRadius(CornerRadius.md)
                                }
                                .buttonStyle(AppButtonStyle(haptic: .none))
                                .padding(.horizontal)
                            }
                        }

                        // Monthly Spending Summary
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("This Month")
                                .font(AppTypography.title2())
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal)

                            MonthlySpendingCard()
                                .padding(.horizontal)
                        }

                        Divider()
                            .padding(.leading)

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
                                        TransactionRowView(transaction: transaction)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section + Spacing.sm)
                }
                .background(AppColors.backgroundSecondary)
                .refreshable {
                    // Force CoreData to re-fetch by touching the context
                    viewContext.refreshAllObjects()
                    HapticManager.lightTap()
                }

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
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
            .sheet(isPresented: $showingSettleSheet) {
                QuickSettleSheetView(people: Array(allPeople))
            }
        }
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
                Text("Tap the + button to get started")
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

