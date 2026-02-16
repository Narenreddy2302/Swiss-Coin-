//
//  BalanceHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct BalanceHeaderView: View {
    let person: Person
    let balance: Double
    let onAvatarTap: () -> Void

    private var balanceText: String {
        let formatted = CurrencyFormatter.format(abs(balance))

        if balance > 0.01 {
            return "\(person.firstName) owes you \(formatted)"
        } else if balance < -0.01 {
            return "You owe \(person.firstName) \(formatted)"
        } else {
            return "All settled up!"
        }
    }

    private var balanceTextView: Text {
        let formatted = CurrencyFormatter.format(abs(balance))

        if balance > 0.01 {
            return Text("\(person.firstName) owes you ") + Text(formatted).fontWeight(.bold)
        } else if balance < -0.01 {
            return Text("You owe \(person.firstName) ") + Text(formatted).fontWeight(.bold)
        } else {
            return Text("All settled up!")
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

    private var balanceBackgroundColor: Color {
        if balance > 0.01 {
            return AppColors.positive.opacity(0.1)
        } else if balance < -0.01 {
            return AppColors.negative.opacity(0.1)
        } else {
            return AppColors.backgroundTertiary
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Avatar and Name
            Button(action: onAvatarTap) {
                VStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: person.colorHex ?? AppColors.defaultAvatarColorHex))
                        .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                        .overlay(
                            Text(person.initials)
                                .font(AppTypography.displayLarge())
                                .foregroundColor(AppColors.onAccent)
                        )
                        .shadow(color: AppColors.shadow, radius: 8, x: 0, y: 4)

                    Text(person.name ?? "Unknown")
                        .font(AppTypography.headingLarge())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Balance Card
            HStack {
                Spacer()
                balanceTextView
                    .font(AppTypography.labelLarge())
                    .foregroundColor(balanceColor)
                Spacer()
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(balanceBackgroundColor)
            )
            .padding(.horizontal, Spacing.xxxl + Spacing.sm)
        }
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
        .background(AppColors.backgroundSecondary)
    }
}
