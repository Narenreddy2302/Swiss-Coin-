//
//  ArchivedSubscriptionsView.swift
//  Swiss Coin
//
//  View for displaying and managing archived subscriptions.
//

import CoreData
import SwiftUI

struct ArchivedSubscriptionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.name, ascending: true)],
        predicate: NSPredicate(format: "isArchived == YES"),
        animation: nil)
    private var archivedSubscriptions: FetchedResults<Subscription>

    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if archivedSubscriptions.isEmpty {
                    EmptyArchivedView()
                } else {
                    archivedList
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticManager.tap()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var archivedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let subscriptionCount = archivedSubscriptions.count
                ForEach(Array(archivedSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                    ArchivedSubscriptionRow(
                        subscription: subscription,
                        onRestore: { restoreSubscription(subscription) },
                        onDelete: { deleteSubscription(subscription) }
                    )

                    if index < subscriptionCount - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                    }
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.section + Spacing.sm)
        }
    }

    private func restoreSubscription(_ subscription: Subscription) {
        subscription.isArchived = false
        subscription.isActive = true

        do {
            try viewContext.save()

            // Reschedule notification if enabled
            if subscription.notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }

            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to restore subscription: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteSubscription(_ subscription: Subscription) {
        HapticManager.delete()

        // Cancel any pending notification before deleting
        NotificationManager.shared.cancelSubscriptionReminder(for: subscription)

        viewContext.delete(subscription)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete subscription: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Archived Subscription Row

private struct ArchivedSubscriptionRow: View {
    @ObservedObject var subscription: Subscription
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color(hex: subscription.colorHex ?? "#808080").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(.system(size: IconSize.md))
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#808080"))
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.format(subscription.amount))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    Text("/\(subscription.cycle ?? "month")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)

                    if subscription.isShared {
                        Text("Shared")
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.accent.opacity(0.1))
                            )
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.tap()
                    onRestore()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Restore subscription")

                Button {
                    HapticManager.tap()
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.negative)
                }
                .accessibilityLabel("Delete subscription permanently")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.background)
        .alert("Delete Permanently", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(subscription.name ?? "this subscription")\"? This action cannot be undone.")
        }
    }
}

// MARK: - Empty Archived View

private struct EmptyArchivedView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No Archived Subscriptions")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)

            Text("Subscriptions you archive will appear here. You can restore them at any time.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}
