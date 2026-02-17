//
//  SubscriptionInfoCard.swift
//  Swiss Coin
//
//  Rich info card displayed at the top of shared subscription conversation.
//  Shows brand, members, next payment, and per-person share.
//

import SwiftUI

struct SubscriptionInfoCard: View {
    let subscription: Subscription
    @Environment(\.colorScheme) var colorScheme

    private var subscriptionColor: Color {
        Color(hex: subscription.colorHex ?? AppColors.defaultAvatarColorHex)
    }

    private var allMembers: [Person] {
        (subscription.subscribers as? Set<Person> ?? [])
            .sorted { $0.displayName < $1.displayName }
    }

    private var countdownText: String {
        let days = subscription.daysUntilNextBilling
        if !subscription.isActive {
            return "Paused"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 0 {
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue"
        } else {
            return "in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    private var countdownColor: Color {
        if !subscription.isActive {
            return AppColors.neutral
        }
        let days = subscription.daysUntilNextBilling
        if days < 0 {
            return AppColors.negative
        } else if days <= 7 {
            return AppColors.warning
        } else {
            return AppColors.positive
        }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Brand section
            brandSection

            // Divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 0.5)

            // Members section
            membersSection

            // Divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 0.5)

            // Bottom metrics
            metricsSection
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .cardShadow(for: colorScheme)
        )
    }

    // MARK: - Brand Section

    private var brandSection: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(subscriptionColor.opacity(0.15))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: subscription.iconName ?? "creditcard.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(subscriptionColor)
                )

            // Name and subtitle
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(subscription.displayName)
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(subscription.cycle ?? "Monthly") \u{00B7} \(CurrencyFormatter.format(subscription.amount))/\(subscription.cycleAbbreviation)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status pill
            StatusPill(status: subscription.billingStatus)
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Members")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(allMembers, id: \.objectID) { member in
                    memberChip(for: member)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memberChip(for member: Person) -> some View {
        let isCurrentUser = CurrentUser.isCurrentUser(member.id)
        let memberColor = Color(hex: member.colorHex ?? AppColors.defaultAvatarColorHex)

        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(memberColor.opacity(0.3))
                .frame(width: IconSize.sm, height: IconSize.sm)
                .overlay(
                    Text(member.initials.prefix(1))
                        .font(AppTypography.caption())
                        .foregroundColor(memberColor)
                )

            Text(isCurrentUser ? "YOU" : member.displayName)
                .font(AppTypography.labelSmall())
                .foregroundColor(isCurrentUser ? AppColors.accent : AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(AppColors.backgroundTertiary)
        )
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        HStack(alignment: .top) {
            // Next payment column
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Next Payment")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text(subscription.nextBillingDate?.formatted(
                    .dateTime.month(.abbreviated).day().year()
                ) ?? "Unknown")
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)

                Text(countdownText)
                    .font(AppTypography.caption())
                    .foregroundColor(countdownColor)
            }

            Spacer()

            // Your share column
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("Your Share")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyFormatter.format(subscription.myShare))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(AppColors.textPrimary)

                Text("(\(subscription.subscriberCount) way split)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}
