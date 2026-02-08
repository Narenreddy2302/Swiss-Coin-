//
//  SharedSubscriptionListView.swift
//  Swiss Coin
//
//  List view for shared subscriptions with balance indicators.
//

import CoreData
import SwiftUI

struct SharedSubscriptionListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)],
        predicate: NSPredicate(format: "isShared == YES AND isArchived == NO"),
        animation: nil)
    private var subscriptions: FetchedResults<Subscription>

    @State private var searchText = ""

    // MARK: - Computed Properties

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSubscriptions: [Subscription] {
        guard isSearching else { return Array(subscriptions) }
        let query = searchText.lowercased()
        return subscriptions.filter { subscription in
            subscription.name?.lowercased().contains(query) == true
        }
    }

    /// Validates that a subscription is still valid in the managed object context
    private func isSubscriptionValid(_ subscription: Subscription) -> Bool {
        // Check that the subscription hasn't been deleted or invalidated
        guard subscription.managedObjectContext != nil,
              !subscription.isDeleted,
              !subscription.isFault else {
            return false
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let subscriptionCount = filteredSubscriptions.count
                ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                    // Only show navigation link if subscription is still valid in context
                    if isSubscriptionValid(subscription) {
                        NavigationLink(destination: SharedSubscriptionConversationView(subscription: subscription)) {
                            SharedSubscriptionListRowView(subscription: subscription)
                        }
                        .buttonStyle(.plain)

                        if index < subscriptionCount - 1 {
                            Divider()
                                .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                        }
                    }
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.section + Spacing.sm)
            .animation(.easeInOut(duration: 0.2), value: filteredSubscriptions.count)
        }
        .background(AppColors.backgroundSecondary)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search shared subscriptions"
        )
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: true)
            } else if isSearching && filteredSubscriptions.isEmpty {
                SharedSubscriptionNoResultsView(searchText: searchText)
            }
        }
    }
}

// MARK: - No Results View

private struct SharedSubscriptionNoResultsView: View {
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

            Text("No shared subscriptions found for \"\(searchText)\"")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}
