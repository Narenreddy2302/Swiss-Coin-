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

    private var attentionSubscriptions: [Subscription] {
        overdueSubscriptions + dueSubscriptions
    }

    private var upcomingSubscriptions: [Subscription] {
        subscriptions.filter { $0.billingStatus == .upcoming && $0.isActive }
    }

    private var pausedSubscriptions: [Subscription] {
        subscriptions.filter { !$0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Attention Required Section (Overdue + Due)
                if !attentionSubscriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Attention Required")
                                .font(AppTypography.subheadlineMedium())
                                .foregroundColor(AppColors.warning)

                            Spacer()

                            Text("\(attentionSubscriptions.count)")
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
                        .padding(.bottom, Spacing.sm)

                        LazyVStack(spacing: 0) {
                            ForEach(attentionSubscriptions) { subscription in
                                NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                    SubscriptionListRowView(subscription: subscription)
                                }
                                .buttonStyle(.plain)

                                if subscription.objectID != attentionSubscriptions.last?.objectID {
                                    Divider()
                                        .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                }
                            }
                        }
                    }
                }

                // Active Subscriptions Section
                if !upcomingSubscriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Active")
                                .font(AppTypography.subheadlineMedium())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("\(upcomingSubscriptions.count)")
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
                        .padding(.bottom, Spacing.sm)

                        LazyVStack(spacing: 0) {
                            ForEach(upcomingSubscriptions) { subscription in
                                NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                    SubscriptionListRowView(subscription: subscription)
                                }
                                .buttonStyle(.plain)

                                if subscription.objectID != upcomingSubscriptions.last?.objectID {
                                    Divider()
                                        .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                }
                            }
                        }
                    }
                }

                // Paused Subscriptions Section
                if !pausedSubscriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Paused")
                                .font(AppTypography.subheadlineMedium())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("\(pausedSubscriptions.count)")
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
                        .padding(.bottom, Spacing.sm)

                        LazyVStack(spacing: 0) {
                            ForEach(pausedSubscriptions) { subscription in
                                NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                    SubscriptionListRowView(subscription: subscription)
                                }
                                .buttonStyle(.plain)

                                if subscription.objectID != pausedSubscriptions.last?.objectID {
                                    Divider()
                                        .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                }
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: Spacing.section + Spacing.sm)
            }
            .padding(.top, Spacing.lg)
        }
        .background(AppColors.backgroundSecondary)
        .overlay {
            if subscriptions.isEmpty {
                EmptySubscriptionView(isShared: false)
            }
        }
    }
}
