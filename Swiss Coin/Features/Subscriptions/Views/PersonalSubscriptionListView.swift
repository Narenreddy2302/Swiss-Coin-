//
//  PersonalSubscriptionListView.swift
//  Swiss Coin
//
//  List view for personal (non-shared) subscriptions with summary header
//  and card-wrapped sections.
//

import CoreData
import SwiftUI

struct PersonalSubscriptionListView: View {
    @Binding var showingAddSubscription: Bool
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showRefreshFeedback = false

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)]
        request.predicate = NSPredicate(format: "isShared == NO AND isArchived == NO")
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    // MARK: - Grouped Subscriptions

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

    // MARK: - Body

    var body: some View {
        if subscriptions.isEmpty {
            ScrollView {
                EmptySubscriptionView(isShared: false) {
                    showingAddSubscription = true
                }
            }
            .refreshable {
                await RefreshHelper.performStandardRefresh(context: viewContext)
            }
        } else {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Summary Header
                    SubscriptionSummaryHeader(isShared: false, subscriptions: Array(subscriptions))

                    // Attention Required Section
                    if !attentionSubscriptions.isEmpty {
                        subscriptionSection(
                            title: "Attention Required",
                            titleColor: AppColors.warning,
                            subscriptions: attentionSubscriptions
                        )
                    }

                    // Active Section
                    if !upcomingSubscriptions.isEmpty {
                        subscriptionSection(
                            title: "Active",
                            titleColor: AppColors.textSecondary,
                            subscriptions: upcomingSubscriptions
                        )
                    }

                    // Paused Section
                    if !pausedSubscriptions.isEmpty {
                        subscriptionSection(
                            title: "Paused",
                            titleColor: AppColors.textSecondary,
                            subscriptions: pausedSubscriptions
                        )
                    }

                    Spacer()
                        .frame(height: Spacing.section + Spacing.sm)
                }
                .padding(.top, Spacing.lg)
            }
            .background(AppColors.backgroundSecondary)
            .refreshable {
                await RefreshHelper.performStandardRefresh(context: viewContext)
                withAnimation(AppAnimation.standard) { showRefreshFeedback = true }
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation(AppAnimation.standard) { showRefreshFeedback = false }
                }
            }
            .refreshFeedback(isShowing: $showRefreshFeedback)
        }
    }

    // MARK: - Section Helper

    @ViewBuilder
    private func subscriptionSection(
        title: String,
        titleColor: Color,
        subscriptions: [Subscription]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header — outside card
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

            // Rows — inside card
            LazyVStack(spacing: 0) {
                let count = subscriptions.count
                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription)) {
                        UnifiedSubscriptionRowView(subscription: subscription, isShared: false)
                    }
                    .buttonStyle(.plain)

                    if index < count - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, Spacing.lg)
        }
    }
}
