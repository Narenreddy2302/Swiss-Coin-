//
//  PhoneLoginView.swift
//  Swiss Coin
//
//  Welcome / onboarding screen shown to new or signed-out users.
//  Tapping "Get Started" authenticates the user locally.
//

import SwiftUI

struct PhoneLoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppColors.accent.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                VStack(spacing: Spacing.lg) {
                    // Animated logo
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)

                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: IconSize.xxl + 32))
                            .foregroundStyle(AppColors.accent)
                            .scaleEffect(isAnimating ? 1.02 : 1.0)
                    }
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                    Text("Swiss Coin")
                        .font(AppTypography.largeTitle())
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Split expenses effortlessly\nwith friends and groups")
                        .font(AppTypography.subheadline())
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, Spacing.section)

                // Feature highlights
                VStack(spacing: Spacing.lg) {
                    FeatureRow(
                        icon: "person.3.fill",
                        title: "Group Expenses",
                        subtitle: "Track shared costs with ease"
                    )

                    FeatureRow(
                        icon: "chart.bar.fill",
                        title: "Smart Insights",
                        subtitle: "Understand your spending habits"
                    )

                    FeatureRow(
                        icon: "bell.badge.fill",
                        title: "Reminders",
                        subtitle: "Never forget who owes what"
                    )
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Get Started button
                Button {
                    HapticManager.tap()
                    authManager.authenticate()
                } label: {
                    Text("Get Started")
                        .font(AppTypography.bodyBold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.lg)
                        .background(AppColors.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.lg)

                // Footer
                Text("Your data stays on this device.\nNo account required.")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.section + Spacing.sm)
                    .padding(.bottom, Spacing.section)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}

#Preview {
    PhoneLoginView()
}
