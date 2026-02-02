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

    // Your share of all shared subscriptions (monthly equivalent)
    private var myMonthlyShare: Double {
        subscriptions
            .filter { $0.isActive }
            .reduce(0) { total, subscription in
                // Convert per-cycle share to monthly equivalent
                let perCycleShare = subscription.myShare
                switch subscription.cycle {
                case "Weekly":
                    return total + (perCycleShare * 4.33)
                case "Monthly":
                    return total + perCycleShare
                case "Yearly":
                    return total + (perCycleShare / 12.0)
                case "Custom":
                    let days = max(1, Int(subscription.customCycleDays))
                    return total + (perCycleShare * (30.44 / Double(days)))
                default:
                    return total + perCycleShare
                }
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
