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
        predicate: NSPredicate(format: "isShared == YES"),
        animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(subscriptions) { subscription in
                    NavigationLink(destination: SharedSubscriptionConversationView(subscription: subscription)) {
                        SharedSubscriptionListRowView(subscription: subscription)
                    }
                    .buttonStyle(.plain)

                    if subscription.objectID != subscriptions.last?.objectID {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                    }
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.section + Spacing.sm)
        }
        .background(AppColors.backgroundSecondary)
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: true)
            }
        }
    }
}
