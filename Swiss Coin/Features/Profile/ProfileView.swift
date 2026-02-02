//
//  ProfileView.swift
//  Swiss Coin
//
//  Simplified, user-friendly profile view with card-based design.
//

import CoreData
import SwiftUI

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showingLogoutAlert = false
    @State private var currentUser: Person?

    // User preferences
    @AppStorage("default_currency") private var defaultCurrency = "USD"

    private var userName: String {
        currentUser?.name ?? "You"
    }

    private var userInitials: String {
        currentUser?.initials ?? "ME"
    }

    private var userColor: String {
        currentUser?.colorHex ?? AppColors.defaultAvatarColorHex
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        // Profile Header Card
                        ProfileHeaderCard(
                            name: userName,
                            initials: userInitials,
                            color: userColor,
                            currency: defaultCurrency
                        )
                        .padding(.horizontal)

                        // Settings Sections
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            // Account Section
                            SettingsSection(title: "Account") {
                                NavigationLink(destination: PersonalDetailsView()) {
                                    SettingsRow(
                                        icon: "person.fill",
                                        title: "Personal Details",
                                        subtitle: "Name, photo, contact info"
                                    )
                                }

                                NavigationLink(destination: NotificationSettingsView()) {
                                    SettingsRow(
                                        icon: "bell.fill",
                                        title: "Notifications",
                                        subtitle: "Manage alerts and reminders"
                                    )
                                }

                                NavigationLink(destination: CurrencySettingsView()) {
                                    SettingsRow(
                                        icon: "dollarsign.circle.fill",
                                        title: "Currency",
                                        subtitle: "Default: \(defaultCurrency)"
                                    )
                                }
                            }

                            // Preferences Section
                            SettingsSection(title: "Preferences") {
                                NavigationLink(destination: AppearanceSettingsView()) {
                                    SettingsRow(
                                        icon: "paintbrush.fill",
                                        title: "Appearance",
                                        subtitle: "Theme and display"
                                    )
                                }

                                NavigationLink(destination: PrivacySecurityView()) {
                                    SettingsRow(
                                        icon: "lock.fill",
                                        title: "Privacy & Security",
                                        subtitle: "Data and account protection"
                                    )
                                }
                            }

                            // Support Section
                            SettingsSection(title: "Support") {
                                Button {
                                    HapticManager.tap()
                                    openURL("https://swisscoin.app/help")
                                } label: {
                                    SettingsRow(
                                        icon: "questionmark.circle.fill",
                                        title: "Help Center",
                                        subtitle: "FAQs and guides",
                                        isExternal: true
                                    )
                                }

                                Button {
                                    HapticManager.tap()
                                    shareApp()
                                } label: {
                                    SettingsRow(
                                        icon: "heart.fill",
                                        title: "Share Swiss Coin",
                                        subtitle: "Invite friends",
                                        isExternal: true
                                    )
                                }
                            }

                            // About Section
                            SettingsSection(title: "About") {
                                HStack {
                                    SettingsRow(
                                        icon: "info.circle.fill",
                                        title: "Version",
                                        subtitle: nil
                                    )
                                    Spacer()
                                    Text(appVersion)
                                        .font(AppTypography.subheadline())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Log Out Button
                        Button {
                            HapticManager.warning()
                            showingLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: IconSize.sm))
                                Text("Log Out")
                                    .font(AppTypography.subheadlineMedium())
                                Spacer()
                            }
                            .foregroundColor(AppColors.negative)
                            .frame(height: ButtonHeight.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.md)
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.tap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                HapticManager.prepare()
                loadCurrentUser()
            }
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {
                    HapticManager.tap()
                }
                Button("Log Out", role: .destructive) {
                    logOut()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }

    // MARK: - Functions

    private func loadCurrentUser() {
        currentUser = CurrentUser.getOrCreate(in: viewContext)
    }

    private func logOut() {
        HapticManager.warning()
        AuthManager.shared.signOut()
        dismiss()
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func shareApp() {
        let shareText = "Check out Swiss Coin - the easiest way to split expenses with friends!"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Profile Header Card

private struct ProfileHeaderCard: View {
    let name: String
    let initials: String
    let color: String
    let currency: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: color).opacity(0.2))
                    .frame(width: 90, height: 90)

                Text(initials)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Color(hex: color))
            }
            .overlay(
                Circle()
                    .stroke(Color(hex: color).opacity(0.3), lineWidth: 2)
            )

            // Name and Currency
            VStack(spacing: Spacing.xs) {
                Text(name)
                    .font(AppTypography.title2())
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                    Text(currency)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Edit Profile Button
            NavigationLink(destination: PersonalDetailsView()) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                    Text("Edit Profile")
                        .font(AppTypography.subheadlineMedium())
                }
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(AppColors.accent.opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, Spacing.sm)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var isExternal: Bool = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Arrow
            if isExternal {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
}
