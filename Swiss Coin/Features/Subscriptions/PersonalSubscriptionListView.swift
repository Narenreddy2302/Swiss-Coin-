//
//  PersonalSubscriptionListView.swift
//  Swiss Coin
//
//  List view for personal (non-shared) subscriptions.
//

import CoreData
import SwiftUI

struct PersonalSubscriptionListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)],
        predicate: NSPredicate(format: "isShared == NO"),
        animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    // Group by billing status
    private var overdueSubscriptions: [Subscription] {
        subscriptions.filter { $0.billingStatus == .overdue && $0.isActive }
    }

    private var dueSubscriptions: [Subscription] {
        subscriptions.filter { $0.billingStatus == .due && $0.isActive }
    }

    private var upcomingSubscriptions: [Subscription] {
        subscriptions.filter { $0.billingStatus == .upcoming && $0.isActive }
    }

    private var pausedSubscriptions: [Subscription] {
        subscriptions.filter { !$0.isActive }
    }

    var body: some View {
        List {
            // Attention Required Section (Overdue + Due)
            if !overdueSubscriptions.isEmpty || !dueSubscriptions.isEmpty {
                Section {
                    ForEach(overdueSubscriptions + dueSubscriptions) { subscription in
                        NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                            SubscriptionListRowView(subscription: subscription)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                } header: {
                    Text("Attention Required")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.warning)
                }
            }

            // Active Subscriptions Section
            if !upcomingSubscriptions.isEmpty {
                Section {
                    ForEach(upcomingSubscriptions) { subscription in
                        NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                            SubscriptionListRowView(subscription: subscription)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                } header: {
                    Text("Active")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Paused Subscriptions Section
            if !pausedSubscriptions.isEmpty {
                Section {
                    ForEach(pausedSubscriptions) { subscription in
                        NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                            SubscriptionListRowView(subscription: subscription)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                } header: {
                    Text("Paused")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.backgroundSecondary)
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: false)
            }
        }
    }
}
