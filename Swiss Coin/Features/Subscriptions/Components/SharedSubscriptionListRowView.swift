//
//  SharedSubscriptionListRowView.swift
//  Swiss Coin
//
//  List row for shared subscriptions with balance indicators, matching GroupListRowView pattern.
//

import CoreData
import SwiftUI

// MARK: - Balance Display Info

/// Pre-computed balance display information to avoid repeated calculations
private struct BalanceDisplayInfo {
    let amount: Double
    let text: String
    let color: Color

    init(balance: Double) {
        self.amount = balance
        let formatted = CurrencyFormatter.formatAbsolute(balance)
        if balance > 0.01 {
            self.text = "you're owed \(formatted)"
            self.color = AppColors.positive
        } else if balance < -0.01 {
            self.text = "you owe \(formatted)"
            self.color = AppColors.negative
        } else {
            self.text = "settled up"
            self.color = AppColors.neutral
        }
    }
}

// MARK: - SharedSubscriptionListRowView

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

    /// Computed once per render pass: calculates balance and derives text/color
    private var balanceInfo: BalanceDisplayInfo {
        BalanceDisplayInfo(balance: subscription.calculateUserBalance())
    }

    var body: some View {
        let displayInfo = balanceInfo
        HStack(spacing: Spacing.md) {
            // Subscription Icon
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: subscription.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "person.2.circle.fill")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(Color(hex: subscription.colorHex ?? "#007AFF"))
                )

            // Name and Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(subscription.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text("\(memberCount + 1) members")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text(displayInfo.text)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(displayInfo.color)
                }
                .lineLimit(1)
            }

            Spacer()

            // Balance amount
            if abs(displayInfo.amount) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(displayInfo.amount))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(displayInfo.color)
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
