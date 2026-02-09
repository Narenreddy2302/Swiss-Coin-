//
//  SearchView.swift
//  Swiss Coin
//
//  Global search view for finding transactions, people, groups, and subscriptions.
//

import CoreData
import SwiftUI

// MARK: - Transaction Filter

private enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case incoming = "Incoming"
    case outgoing = "Outgoing"
    case subscriptions = "Subscriptions"
}

struct SearchView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all

    @State private var selectedTransaction: FinancialTransaction?

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

    // MARK: - Search Filtered Results

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    // MARK: - Filter Logic

    private func userNetPosition(for transaction: FinancialTransaction) -> Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var displayedTransactions: [FinancialTransaction] {
        let base: [FinancialTransaction]
        if isSearching {
            let query = searchText.lowercased()
            base = allTransactions.filter { $0.title?.lowercased().contains(query) == true }
        } else {
            base = Array(allTransactions)
        }

        switch selectedFilter {
        case .all, .subscriptions:
            return base
        case .incoming:
            return base.filter { userNetPosition(for: $0) > 0.01 }
        case .outgoing:
            return base.filter { userNetPosition(for: $0) < -0.01 }
        }
    }

    private var displayedSubscriptions: [Subscription] {
        if isSearching {
            let query = searchText.lowercased()
            return allSubscriptions.filter { $0.name?.lowercased().contains(query) == true }
        }
        return Array(allSubscriptions)
    }

    private var hasSearchResults: Bool {
        !displayedTransactions.isEmpty ||
        !filteredPeople.isEmpty ||
        !filteredGroups.isEmpty ||
        !filteredSubscriptions.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    filterChipsBar

                    Group {
                        if selectedFilter == .subscriptions {
                            subscriptionsListView
                        } else if isSearching {
                            searchResultsView
                        } else {
                            transactionListView
                        }
                    }
                    .allowsHitTesting(selectedTransaction == nil)
                }

                // Full-screen detail overlay
                if let selected = selectedTransaction {
                    TransactionExpandedView(
                        transaction: selected,
                        selectedTransaction: $selectedTransaction
                    )
                    .zIndex(2)
                }
            }
            .navigationTitle("Transactions")
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

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        HapticManager.selectionChanged()
                    } label: {
                        Text(filter.rawValue)
                            .font(AppTypography.labelLarge())
                            .foregroundColor(selectedFilter == filter ? AppColors.buttonForeground : AppColors.textSecondary)
                            .frame(height: 34)
                            .padding(.horizontal, Spacing.md)
                            .background(
                                selectedFilter == filter
                                    ? AppColors.buttonBackground
                                    : AppColors.surface
                            )
                            .cornerRadius(CornerRadius.md)
                    }
                    .buttonStyle(AppButtonStyle(haptic: .none))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: - Transaction List View (Default State)

    private var transactionListView: some View {
        Group {
            if displayedTransactions.isEmpty {
                filterEmptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedTransactions, id: \.id) { transaction in
                            TransactionRowView(
                                transaction: transaction,
                                selectedTransaction: $selectedTransaction
                            )
                            if transaction.id != displayedTransactions.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.bottom, Spacing.section)
                    .animation(.easeInOut(duration: 0.2), value: displayedTransactions.count)
                }
            }
        }
    }

    // MARK: - Subscriptions List View

    private var subscriptionsListView: some View {
        Group {
            if displayedSubscriptions.isEmpty {
                filterEmptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedSubscriptions) { subscription in
                            NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                SearchSubscriptionRow(subscription: subscription)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.selectionChanged()
                            })

                            if subscription.id != displayedSubscriptions.last?.id {
                                Divider()
                                    .padding(.leading, AvatarSize.lg + Spacing.md + Spacing.lg)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.section)
                }
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        Group {
            if hasSearchResults {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                        // Transactions Results
                        if !displayedTransactions.isEmpty {
                            SearchResultSection(
                                title: "Transactions",
                                icon: "arrow.left.arrow.right",
                                count: displayedTransactions.count
                            ) {
                                ForEach(displayedTransactions, id: \.id) { transaction in
                                    TransactionRowView(
                                        transaction: transaction,
                                        selectedTransaction: $selectedTransaction
                                    )
                                    if transaction.id != displayedTransactions.last?.id {
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

                        // Subscriptions Results (only when not in subscriptions filter)
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
                    .animation(.easeInOut(duration: 0.2), value: displayedTransactions.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredPeople.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredGroups.count)
                    .animation(.easeInOut(duration: 0.2), value: filteredSubscriptions.count)
                }
            } else {
                SearchNoResultsView(searchText: searchText)
            }
        }
    }

    // MARK: - Filter Empty View

    private var filterEmptyView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: selectedFilter == .subscriptions ? "creditcard" : "arrow.left.arrow.right")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No \(selectedFilter.rawValue) Transactions")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .font(AppTypography.headingMedium())
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
                        .font(AppTypography.headingLarge())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(person.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if abs(balance) > 0.01 {
                    (balance > 0
                        ? Text("owes you ") + Text(CurrencyFormatter.formatAbsolute(balance)).fontWeight(.bold)
                        : Text("you owe ") + Text(CurrencyFormatter.formatAbsolute(balance)).fontWeight(.bold))
                        .font(AppTypography.bodySmall())
                        .foregroundColor(balanceColor)
                } else {
                    Text("settled up")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.neutral)
                }
            }

            Spacer()
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
                        .font(AppTypography.headingMedium())
                        .foregroundColor(Color(hex: group.colorHex ?? "#007AFF"))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(group.name ?? "Unknown Group")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
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
                        .font(AppTypography.headingMedium())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#FF9500"))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.format(subscription.amount))
                        .font(AppTypography.bodySmall())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textSecondary)

                    if let cycle = subscription.cycle {
                        Text("• \(cycle)")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
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
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            Text("No matches found for \"\(searchText)\"")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
