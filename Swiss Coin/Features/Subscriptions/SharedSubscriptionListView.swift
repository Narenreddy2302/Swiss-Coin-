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

    // Total monthly cost across all shared subscriptions
    private var totalMonthly: Double {
        subscriptions
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.monthlyEquivalent }
    }

    // Your share of all shared subscriptions
    private var myMonthlyShare: Double {
        subscriptions
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.myShare * (30.44 / cycleToDays($1.cycle ?? "Monthly")) }
    }

    private func cycleToDays(_ cycle: String) -> Double {
        switch cycle {
        case "Weekly": return 7
        case "Monthly": return 30.44
        case "Yearly": return 365.25
        default: return 30.44
        }
    }

    var body: some View {
        List {
            // Summary Section
            Section {
                SharedSubscriptionSummaryCard(
                    totalMonthly: totalMonthly,
                    myShare: myMonthlyShare,
                    activeCount: subscriptions.filter { $0.isActive }.count
                )
            }
            .listRowInsets(EdgeInsets(top: Spacing.lg, leading: Spacing.lg, bottom: Spacing.sm, trailing: Spacing.lg))
            .listRowBackground(Color.clear)

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
