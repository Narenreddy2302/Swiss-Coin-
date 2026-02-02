//
//  SearchView.swift
//  Swiss Coin
//
//  Global search view for finding transactions, people, groups, and subscriptions.
//

import CoreData
import SwiftUI

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""

    // MARK: - Fetch Requests

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<FinancialTransaction> = FinancialTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)]
        request.fetchLimit = 200  // Limit for search performance
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var allTransactions: FetchedResults<FinancialTransaction>

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var allPeople: FetchedResults<Person>

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var allGroups: FetchedResults<UserGroup>

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.name, ascending: true)]
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var allSubscriptions: FetchedResults<Subscription>

    // MARK: - Filtered Results

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredTransactions: [FinancialTransaction] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allTransactions.filter { transaction in
            transaction.title?.lowercased().contains(query) == true
        }
    }

    private var filteredPeople: [Person] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allPeople.filter { person in
            !CurrentUser.isCurrentUser(person.id) &&
            person.name?.lowercased().contains(query) == true
        }
    }

    private var filteredGroups: [UserGroup] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allGroups.filter { group in
            group.name?.lowercased().contains(query) == true
        }
    }

    private var filteredSubscriptions: [Subscription] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allSubscriptions.filter { subscription in
            subscription.name?.lowercased().contains(query) == true
        }
    }

    private var hasResults: Bool {
        !filteredTransactions.isEmpty ||
        !filteredPeople.isEmpty ||
        !filteredGroups.isEmpty ||
        !filteredSubscriptions.isEmpty
    }

    // MARK: - Suggested Data

    private var recentTransactions: [FinancialTransaction] {
        Array(allTransactions.prefix(3))
    }


    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                if isSearching {
                    searchResultsView
                } else {
                    suggestionsView
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Transactions, people, groups…"
        )
        .onAppear {
            HapticManager.prepare()
        }
    }

    // MARK: - Suggestions View (Empty Search State)

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // Recent Transactions Section
                if !recentTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Recent Transactions")
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal)

                        LazyVStack(spacing: 0) {
                            ForEach(recentTransactions, id: \.id) { transaction in
                                TransactionRowView(transaction: transaction)
                                Divider()
                            }
                        }
                    }
                }

                // Browse Categories Hint
                if recentTransactions.isEmpty {
                    SearchEmptyPromptView()
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.section)
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        Group {
            if hasResults {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                        // Transactions Results
                        if !filteredTransactions.isEmpty {
                            SearchResultSection(
                                title: "Transactions",
                                icon: "arrow.left.arrow.right",
                                count: filteredTransactions.count
                            ) {
                                ForEach(filteredTransactions, id: \.id) { transaction in
                                    TransactionRowView(transaction: transaction)
                                    if transaction.id != filteredTransactions.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }

                        // People Results
                        if !filteredPeople.isEmpty {
                            SearchResultSection(
                                title: "People",
                                icon: "person.2.fill",
                                count: filteredPeople.count
                            ) {
                                ForEach(filteredPeople) { person in
                                    NavigationLink(destination: PersonConversationView(person: person)) {
                                        SearchPersonRow(person: person)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(TapGesture().onEnded {
                                        HapticManager.selectionChanged()
                                    })

                                    if person.id != filteredPeople.last?.id {
                                        Divider()
                                            .padding(.leading, AvatarSize.lg + Spacing.md + Spacing.lg)
                                    }
                                }
                            }
                        }

                        // Groups Results
                        if !filteredGroups.isEmpty {
                            SearchResultSection(
                                title: "Groups",
                                icon: "person.3.fill",
                                count: filteredGroups.count
                            ) {
                                ForEach(filteredGroups) { group in
                                    NavigationLink(destination: GroupConversationView(group: group)) {
                                        SearchGroupRow(group: group)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(TapGesture().onEnded {
                                        HapticManager.selectionChanged()
                                    })

                                    if group.id != filteredGroups.last?.id {
                                        Divider()
                                            .padding(.leading, AvatarSize.lg + Spacing.md + Spacing.lg)
                                    }
                                }
                            }
                        }

                        // Subscriptions Results
                        if !filteredSubscriptions.isEmpty {
                            SearchResultSection(
                                title: "Subscriptions",
                                icon: "creditcard.fill",
                                count: filteredSubscriptions.count
                            ) {
                                ForEach(filteredSubscriptions) { subscription in
                                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                        SearchSubscriptionRow(subscription: subscription)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(TapGesture().onEnded {
                                        HapticManager.selectionChanged()
                                    })

                                    if subscription.id != filteredSubscriptions.last?.id {
                                        Divider()
                                            .padding(.leading, AvatarSize.lg + Spacing.md + Spacing.lg)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section)
                    .animation(.easeInOut(duration: 0.2), value: filteredTransactions.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredPeople.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredGroups.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredSubscriptions.count)
                }
            } else {
                SearchNoResultsView(searchText: searchText)
            }
        }
    }
}

// MARK: - Search Result Section

private struct SearchResultSection<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.sm, weight: .medium))
                    .foregroundColor(AppColors.accent)

                Text(title)
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.surface.opacity(0.8))
                    )
            }
            .padding(.horizontal)

            content()
        }
    }
}

// MARK: - Person Row for Search

private struct SearchPersonRow: View {
    @ObservedObject var person: Person

    private var balance: Double {
        person.calculateBalance()
    }

    private var balanceColor: Color {
        if balance > 0.01 { return AppColors.positive }
        else if balance < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.title3())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(person.name ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                if abs(balance) > 0.01 {
                    Text(balance > 0 ? "owes you \(CurrencyFormatter.formatAbsolute(balance))" : "you owe \(CurrencyFormatter.formatAbsolute(balance))")
                        .font(AppTypography.subheadline())
                        .foregroundColor(balanceColor)
                } else {
                    Text("settled up")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.neutral)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: IconSize.xs, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
    }
}

// MARK: - Group Row for Search

private struct SearchGroupRow: View {
    @ObservedObject var group: UserGroup

    private var memberCount: Int {
        group.members?.count ?? 0
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: group.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(AppTypography.headline())
                        .foregroundColor(Color(hex: group.colorHex ?? "#007AFF"))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(group.name ?? "Unknown Group")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: IconSize.xs, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
    }
}

// MARK: - Subscription Row for Search

private struct SearchSubscriptionRow: View {
    @ObservedObject var subscription: Subscription

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#FF9500").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(AppTypography.headline())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#FF9500"))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.format(subscription.amount))
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    if let cycle = subscription.cycle {
                        Text("• \(cycle)")
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: IconSize.xs, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
    }
}

// MARK: - Suggested Person Chip

private struct SuggestedPersonChip: View {
    @ObservedObject var person: Person

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            Text(person.firstName)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 64)
    }
}

// MARK: - No Results View

private struct SearchNoResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No Results")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("No matches found for \"\(searchText)\"")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Prompt View (No Data Yet)

private struct SearchEmptyPromptView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: Spacing.section)

            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("Search Everything")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Find transactions, people, groups, and subscriptions — all in one place.")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: IconSize.sm))
                Text("Type in the search bar to get started")
                    .font(AppTypography.subheadline())
            }
            .foregroundColor(AppColors.accent)
            .padding(.top, Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
