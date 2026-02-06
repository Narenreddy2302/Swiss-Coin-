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
        List {
            // Subscriptions with balance indicators
            Section {
                ForEach(subscriptions) { subscription in
                    NavigationLink(destination: SharedSubscriptionConversationView(subscription: subscription)) {
                        SharedSubscriptionListRowView(subscription: subscription)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(AppColors.backgroundSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: true)
            }
        }
    }
}
