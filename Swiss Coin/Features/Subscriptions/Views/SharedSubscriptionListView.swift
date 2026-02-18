//
//  SharedSubscriptionListView.swift
//  Swiss Coin
//
//  List view for shared subscriptions with summary header
//  and flat sections.
//

import CoreData
import SwiftUI

struct SharedSubscriptionListView: View {
    @Binding var showingAddSubscription: Bool
    @Binding var searchText: String
    @Binding var selectedSegment: Int
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)]
        request.predicate = NSPredicate(format: "isShared == YES AND isArchived == NO")
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    // MARK: - Grouped Subscriptions (single-pass)

    private var categorizedSubscriptions: (attention: [Subscription], upcoming: [Subscription], paused: [Subscription]) {
        var attention: [Subscription] = []
        var upcoming: [Subscription] = []
        var paused: [Subscription] = []

        let source: [Subscription] = searchText.isEmpty
            ? Array(subscriptions)
            : subscriptions.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }

        for sub in source {
            guard sub.managedObjectContext != nil, !sub.isDeleted, !sub.isFault else { continue }

            if !sub.isActive {
                paused.append(sub)
            } else {
                switch sub.billingStatus {
                case .overdue, .due:
                    attention.append(sub)
                case .upcoming:
                    upcoming.append(sub)
                case .paused:
                    paused.append(sub)
                }
            }
        }
        return (attention, upcoming, paused)
    }

    // MARK: - Body

    var body: some View {
        if subscriptions.isEmpty && searchText.isEmpty {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    SubscriptionScrollHeader(searchText: $searchText, selectedSegment: $selectedSegment)
                    EmptySubscriptionView(isShared: true) {
                        showingAddSubscription = true
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await RefreshHelper.performStandardRefresh(context: viewContext)
            }
        } else {
            ScrollView {
                let categories = categorizedSubscriptions

                VStack(spacing: Spacing.md) {
                    SubscriptionScrollHeader(searchText: $searchText, selectedSegment: $selectedSegment)
                    // Attention Required Section
                    if !categories.attention.isEmpty {
                        subscriptionSection(
                            title: "Attention Required",
                            titleColor: AppColors.warning,
                            subscriptions: categories.attention
                        )
                    }

                    // Active Section
                    if !categories.upcoming.isEmpty {
                        subscriptionSection(
                            title: "Active",
                            titleColor: AppColors.textSecondary,
                            subscriptions: categories.upcoming
                        )
                    }

                    // Paused Section
                    if !categories.paused.isEmpty {
                        subscriptionSection(
                            title: "Paused",
                            titleColor: AppColors.textSecondary,
                            subscriptions: categories.paused
                        )
                    }

                    // No search results
                    if !searchText.isEmpty && categories.attention.isEmpty && categories.upcoming.isEmpty && categories.paused.isEmpty {
                        noSearchResultsView
                    }

                    Spacer()
                        .frame(height: Spacing.section + Spacing.sm)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.backgroundSecondary)
            .refreshable {
                await RefreshHelper.performStandardRefresh(context: viewContext)
            }
        }
    }

    // MARK: - No Search Results

    private var noSearchResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.xl))
                .foregroundColor(AppColors.textTertiary)

            Text("No results for \"\(searchText)\"")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section Helper

    @ViewBuilder
    private func subscriptionSection(
        title: String,
        titleColor: Color,
        subscriptions: [Subscription]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                Text(title)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(titleColor)

                Spacer()

                Text("\(subscriptions.count)")
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

            // Rows (already validated during categorization)
            LazyVStack(spacing: 0) {
                let count = subscriptions.count
                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
                    NavigationLink(destination: SharedSubscriptionConversationView(subscription: subscription)) {
                        UnifiedSubscriptionRowView(subscription: subscription, isShared: true)
                    }
                    .buttonStyle(.plain)

                    if index < count - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                    }
                }
            }
        }
    }
}
