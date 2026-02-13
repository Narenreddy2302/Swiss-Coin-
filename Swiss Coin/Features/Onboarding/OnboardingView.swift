//
//  OnboardingView.swift
//  Swiss Coin
//
//  Brief onboarding walkthrough shown on first launch.
//  3 informational pages + a "Get Started" page.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "Track Expenses",
            description: "Keep a clear record of every expense.\nKnow exactly where your money goes.",
            color: .blue
        ),
        OnboardingPage(
            icon: "person.2.circle.fill",
            title: "Split with Friends",
            description: "Easily split bills and track who owes what.\nNo more awkward money conversations.",
            color: .blue
        ),
        OnboardingPage(
            icon: "creditcard.circle.fill",
            title: "Manage Subscriptions",
            description: "Track personal and shared subscriptions.\nNever miss a payment or overpay.",
            color: .orange
        ),
    ]

    var body: some View {
        ZStack {
            // Background
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count {
                        Button {
                            HapticManager.lightTap()
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.trailing, Spacing.xl)
                        .padding(.top, Spacing.lg)
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPageView(page: page)
                            .tag(index)
                    }

                    // Final "Get Started" page
                    getStartedView
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppAnimation.standard, value: currentPage)

                // Page indicators + button
                VStack(spacing: Spacing.xxl) {
                    // Custom page dots
                    HStack(spacing: Spacing.sm) {
                        ForEach(0...pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8,
                                       height: index == currentPage ? 10 : 8)
                                .animation(AppAnimation.quick, value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage < pages.count {
                        Button {
                            HapticManager.tap()
                            withAnimation(AppAnimation.standard) {
                                currentPage += 1
                            }
                        } label: {
                            Text("Next")
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.buttonForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: ButtonHeight.lg)
                                .background(AppColors.buttonBackground)
                                .cornerRadius(CornerRadius.md)
                        }
                        .buttonStyle(AppButtonStyle(haptic: .none))
                        .padding(.horizontal, Spacing.xxl)
                    } else {
                        Button {
                            HapticManager.success()
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.buttonForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: ButtonHeight.lg)
                                .background(AppColors.buttonBackground)
                                .cornerRadius(CornerRadius.md)
                        }
                        .buttonStyle(AppButtonStyle(haptic: .none))
                        .padding(.horizontal, Spacing.xxl)
                    }
                }
                .padding(.bottom, Spacing.section)
            }
        }
    }

    // MARK: - Page View

    private func onboardingPageView(page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Icon with animated background
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(page.color)
            }

            // Text
            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(AppTypography.displayLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Get Started View

    private var getStartedView: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: Spacing.md) {
                Text("You're All Set!")
                    .font(AppTypography.displayLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Start tracking your expenses,\nsplitting bills, and managing subscriptions.")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        hasSeenOnboarding = true
    }
}

// MARK: - Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
