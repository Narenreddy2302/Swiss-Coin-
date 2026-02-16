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

    @State private var showRefreshFeedback = false

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)]
        request.predicate = NSPredicate(format: "isShared == YES AND isArchived == NO")
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    /// Validates that a subscription is still valid in the managed object context
    private func isSubscriptionValid(_ subscription: Subscription) -> Bool {
        guard subscription.managedObjectContext != nil,
              !subscription.isDeleted,
              !subscription.isFault else {
            return false
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        if subscriptions.isEmpty {
            ScrollView {
                EmptySubscriptionView(isShared: true)
            }
            .refreshable {
                await RefreshHelper.performStandardRefresh(context: viewContext)
            }
        } else {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        // Section header
                        HStack {
                            Text("All Shared")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)

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

                        // Subscription rows
                        LazyVStack(spacing: 0) {
                            let subscriptionCount = subscriptions.count
                            ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
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
}
