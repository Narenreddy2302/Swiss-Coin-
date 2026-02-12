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
        predicate: NSPredicate(format: "isShared == NO AND isArchived == NO"),
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

    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.isActive }
    }

    private var upcomingSubscriptions: [Subscription] {
        subscriptions.filter { $0.billingStatus == .upcoming && $0.isActive }
    }

    private var pausedSubscriptions: [Subscription] {
        subscriptions.filter { !$0.isActive }
    }

    private var monthlyTotal: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    private var nextDueDate: Date? {
        activeSubscriptions
            .compactMap { $0.nextBillingDate }
            .filter { $0 >= Date() }
            .min()
    }

    var body: some View {
        if subscriptions.isEmpty {
            EmptySubscriptionView(isShared: false)
        } else {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Summary Card
                    PersonalSubscriptionSummaryCard(
                        monthlyTotal: monthlyTotal,
                        activeCount: activeSubscriptions.count,
                        nextDueDate: nextDueDate
                    )
                    .padding(.horizontal, Spacing.lg)

                    // Attention Required Section (Overdue + Due)
                    if !attentionSubscriptions.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Attention Required")
                                    .font(AppTypography.labelLarge())
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

                            LazyVStack(spacing: 0) {
                                let attentionCount = attentionSubscriptions.count
                                ForEach(Array(attentionSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                        SubscriptionListRowView(subscription: subscription)
                                    }
                                    .buttonStyle(.plain)

                                    if index < attentionCount - 1 {
                                        Divider()
                                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                    }
                                }
                            }
                        }
                    }

                    // Active Subscriptions Section
                    if !upcomingSubscriptions.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Active")
                                    .font(AppTypography.labelLarge())
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

                            LazyVStack(spacing: 0) {
                                let upcomingCount = upcomingSubscriptions.count
                                ForEach(Array(upcomingSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                        SubscriptionListRowView(subscription: subscription)
                                    }
                                    .buttonStyle(.plain)

                                    if index < upcomingCount - 1 {
                                        Divider()
                                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                    }
                                }
                            }
                        }
                    }

                    // Paused Subscriptions Section
                    if !pausedSubscriptions.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Paused")
                                    .font(AppTypography.labelLarge())
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

                            LazyVStack(spacing: 0) {
                                let pausedCount = pausedSubscriptions.count
                                ForEach(Array(pausedSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                                        SubscriptionListRowView(subscription: subscription)
                                    }
                                    .buttonStyle(.plain)

                                    if index < pausedCount - 1 {
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
        }
    }
}
