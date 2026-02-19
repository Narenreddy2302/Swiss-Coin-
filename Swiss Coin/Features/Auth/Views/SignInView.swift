//
//  SignInView.swift
//  Swiss Coin
//
//  Sign in with Apple screen — mandatory authentication gate.
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 72

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App branding
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)

                    Text("Swiss Coin")
                        .font(AppTypography.displayLarge())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Track expenses, split bills, and settle up with friends.")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxxl)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                // Error message + retry
                if let error = authManager.errorMessage {
                    VStack(spacing: Spacing.sm) {
                        Text(error)
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.negative)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(error)")

                        Button {
                            HapticManager.lightTap()
                            authManager.errorMessage = nil
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: IconSize.sm))
                                Text("Try Again")
                                    .font(AppTypography.buttonSmall())
                            }
                            .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Try again")
                        .accessibilityHint("Clears the error so you can sign in again")
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.md)
                    .transition(.opacity)
                }

                // Sign in button or loading
                if authManager.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                        .padding(.bottom, Spacing.xxxl)
                        .accessibilityLabel("Signing in")
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        authManager.prepareAppleSignIn(request: request)
                    } onCompletion: { result in
                        handleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(
                        colorScheme == .dark ? .white : .black
                    )
                    .frame(height: ButtonHeight.lg)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
        .animation(AppAnimation.standard, value: authManager.isLoading)
        .animation(AppAnimation.standard, value: authManager.errorMessage)
    }

    // MARK: - Actions

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                let authorization = try result.get()
                guard let credential = authorization.credential
                        as? ASAuthorizationAppleIDCredential
                else {
                    authManager.errorMessage = "Invalid Apple credential."
                    HapticManager.error()
                    return
                }

                try await authManager.signInWithApple(credential: credential)
                HapticManager.success()
            } catch {
                if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                    // User cancelled — do nothing
                    return
                }
                authManager.errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
    }
}
