//
//  SharedSubscriptionListRowView.swift
//  Swiss Coin
//
//  List row for shared subscriptions with balance indicators, matching GroupListRowView pattern.
//

import SwiftUI

struct SharedSubscriptionListRowView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPressed = false
    @State private var showingRecordPayment = false
    @State private var showingReminder = false
    @State private var showingDetail = false

    private var memberCount: Int {
        subscription.memberCount
    }

    // Calculate if members owe you or you owe them
    private var balance: Double {
        subscription.calculateUserBalance()
    }

    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            return "you're owed \(formatted)"
        } else if balance < -0.01 {
            return "you owe \(formatted)"
        } else {
            return "settled up"
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Subscription Icon
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                        .font(AppTypography.headline())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                )

            // Name and Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text("\(memberCount + 1) members")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(balanceText)
                        .font(AppTypography.subheadline())
                        .foregroundColor(balanceColor)
                }
                .lineLimit(1)
            }

            Spacer()

            // Balance amount
            if abs(balance) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(balance))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                HapticManager.lightTap()
                showingDetail = true
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Button {
                HapticManager.lightTap()
                showingRecordPayment = true
            } label: {
                Label("Record Payment", systemImage: "dollarsign.circle")
            }

            Button {
                HapticManager.lightTap()
                showingReminder = true
            } label: {
                Label("Send Reminders", systemImage: "bell")
            }
        }
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                SubscriptionDetailView(subscription: subscription)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDetail = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecordPayment) {
            RecordSubscriptionPaymentView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingReminder) {
            SubscriptionReminderSheetView(subscription: subscription)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}
