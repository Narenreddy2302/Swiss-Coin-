//
//  ProfileView.swift
//  Swiss Coin
//
//  Main profile view with settings navigation.
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
            List {
                // Header Profile Section
                Section {
                    HStack(spacing: Spacing.lg) {
                        Circle()
                            .fill(Color(hex: userColor).opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(userInitials)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(hex: userColor))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: userColor), lineWidth: 2)
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(AppTypography.title2())
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.accent)
                                Text(defaultCurrency)
                                    .font(AppTypography.subheadline())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.tap()
                    }
                    .background(
                        NavigationLink(destination: PersonalDetailsView()) {
                            EmptyView()
                        }
                        .opacity(0)
                    )
                }

                // Account Settings
                Section {
                    NavigationLink(destination: PersonalDetailsView()) {
                        SettingsRow(icon: "person.text.rectangle", title: "Personal Details", color: .blue)
                    }

                    NavigationLink(destination: NotificationSettingsView()) {
                        SettingsRow(icon: "bell.fill", title: "Notifications", color: .red)
                    }

                    NavigationLink(destination: PrivacySecurityView()) {
                        SettingsRow(icon: "lock.fill", title: "Privacy & Security", color: .green)
                    }
                } header: {
                    Text("Account")
                        .font(AppTypography.subheadlineMedium())
                }

                // App Settings
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        SettingsRow(icon: "paintbrush.fill", title: "Appearance", color: .purple)
                    }

                    NavigationLink(destination: CurrencySettingsView()) {
                        SettingsRow(icon: "dollarsign.circle.fill", title: "Currency", color: .orange)
                    }
                } header: {
                    Text("Preferences")
                        .font(AppTypography.subheadlineMedium())
                }

                // Support Section
                Section {
                    Button {
                        HapticManager.tap()
                        openURL("https://swisscoin.app/help")
                    } label: {
                        SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .teal)
                    }

                    Button {
                        HapticManager.tap()
                        openURL("https://swisscoin.app/feedback")
                    } label: {
                        SettingsRow(icon: "envelope.fill", title: "Send Feedback", color: .indigo)
                    }

                    Button {
                        HapticManager.tap()
                        shareApp()
                    } label: {
                        SettingsRow(icon: "heart.fill", title: "Share Swiss Coin", color: .pink)
                    }
                } header: {
                    Text("Support")
                        .font(AppTypography.subheadlineMedium())
                }

                // About Section
                Section {
                    HStack {
                        SettingsRow(icon: "info.circle.fill", title: "Version", color: .gray)
                        Spacer()
                        Text(appVersion)
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("About")
                        .font(AppTypography.subheadlineMedium())
                }

                // Log Out Section
                Section {
                    Button {
                        HapticManager.warning()
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .font(AppTypography.bodyBold())
                                .foregroundColor(AppColors.negative)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProfileView()
}
