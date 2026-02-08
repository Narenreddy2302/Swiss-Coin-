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
                let subscriptionCount = subscriptions.count
                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
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
            .animation(.easeInOut(duration: 0.2), value: subscriptions.count)
        }
        .background(AppColors.backgroundSecondary)
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: true)
            }
        }
    }
}

