//
//  NotificationSettingsView.swift
//  Swiss Coin
//
//  Simplified notification settings with card-based design.
//

import Combine
import SwiftUI
import UserNotifications

// MARK: - ViewModel

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    // Master Toggle
    @Published var allNotificationsEnabled: Bool = true

    // Transaction Notifications
    @Published var newExpenseAdded: Bool = true
    @Published var someonePaidYou: Bool = true

    // Reminder Notifications
    @Published var paymentReminders: Bool = true
    @Published var reminderDaysBefore: Int = 3

    // Subscription Notifications
    @Published var subscriptionDueSoon: Bool = true
    @Published var subscriptionDueDays: Int = 3

    // Summary Notifications
    @Published var weeklySummary: Bool = true

    // State
    @Published var isLoading: Bool = false
    @Published var systemNotificationsEnabled: Bool = true
    @Published var showSystemSettingsPrompt: Bool = false
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined

    private var cancellables = Set<AnyCancellable>()

    @AppStorage("notifications_enabled") private var storedAllNotifications = true
    @AppStorage("notify_new_expense") private var storedNewExpense = true
    @AppStorage("notify_someone_paid") private var storedSomeonePaid = true
    @AppStorage("notify_payment_reminders") private var storedPaymentReminders = true
    @AppStorage("reminder_days_before") private var storedReminderDays = 3
    @AppStorage("notify_subscription_due") private var storedSubscriptionDue = true
    @AppStorage("subscription_due_days") private var storedSubscriptionDays = 3
    @AppStorage("notify_weekly_summary") private var storedWeeklySummary = true

    init() {
        loadFromLocalStorage()
        setupAutoSave()
    }

    func loadSettings() async {
        isLoading = true
        await NotificationManager.shared.refreshPermissionStatus()
        let status = NotificationManager.shared.permissionStatus
        permissionStatus = status
        systemNotificationsEnabled = status == .authorized
        loadFromLocalStorage()
        isLoading = false
    }

    func requestNotificationPermission() async {
        let granted = await NotificationManager.shared.requestPermission()
        let status = NotificationManager.shared.permissionStatus
        permissionStatus = status
        systemNotificationsEnabled = granted
        if !granted && status == .denied {
            showSystemSettingsPrompt = true
        }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func loadFromLocalStorage() {
        allNotificationsEnabled = storedAllNotifications
        newExpenseAdded = storedNewExpense
        someonePaidYou = storedSomeonePaid
        paymentReminders = storedPaymentReminders
        reminderDaysBefore = storedReminderDays
        subscriptionDueSoon = storedSubscriptionDue
        subscriptionDueDays = storedSubscriptionDays
        weeklySummary = storedWeeklySummary
    }

    private func syncToLocalStorage() {
        storedAllNotifications = allNotificationsEnabled
        storedNewExpense = newExpenseAdded
        storedSomeonePaid = someonePaidYou
        storedPaymentReminders = paymentReminders
        storedReminderDays = reminderDaysBefore
        storedSubscriptionDue = subscriptionDueSoon
        storedSubscriptionDays = subscriptionDueDays
        storedWeeklySummary = weeklySummary
    }

    private func setupAutoSave() {
        let publishers = Publishers.MergeMany([
            $allNotificationsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $newExpenseAdded.map { _ in () }.eraseToAnyPublisher(),
            $someonePaidYou.map { _ in () }.eraseToAnyPublisher(),
            $paymentReminders.map { _ in () }.eraseToAnyPublisher(),
            $subscriptionDueSoon.map { _ in () }.eraseToAnyPublisher(),
            $weeklySummary.map { _ in () }.eraseToAnyPublisher(),
            $reminderDaysBefore.map { _ in () }.eraseToAnyPublisher(),
            $subscriptionDueDays.map { _ in () }.eraseToAnyPublisher()
        ])

        publishers
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncToLocalStorage()
            }
            .store(in: &cancellables)
    }
}

// MARK: - View

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // System Status Card
                    if viewModel.permissionStatus == .denied {
                        SystemStatusCard(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: AppColors.warning,
                            title: "Notifications Blocked",
                            message: "Enable notifications in System Settings to receive alerts.",
                            buttonTitle: "Open Settings",
                            action: { viewModel.openSystemSettings() }
                        )
                        .padding(.horizontal)
                    } else if viewModel.permissionStatus == .notDetermined {
                        SystemStatusCard(
                            icon: "bell.badge.fill",
                            iconColor: AppColors.accent,
                            title: "Enable Notifications",
                            message: "Allow Swiss Coin to send you payment reminders and updates.",
                            buttonTitle: "Allow",
                            action: {
                                Task {
                                    await viewModel.requestNotificationPermission()
                                }
                            }
                        )
                        .padding(.horizontal)
                    }

                    // Main Toggle
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.accent)
                            Text("All Notifications")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $viewModel.allNotificationsEnabled)
                                .labelsHidden()
                                .onChange(of: viewModel.allNotificationsEnabled) { _, newValue in
                                    HapticManager.toggle()
                                    if newValue && viewModel.permissionStatus == .notDetermined {
                                        Task {
                                            await viewModel.requestNotificationPermission()
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    if viewModel.allNotificationsEnabled {
                        // Transaction Notifications
                        SettingsGroup(title: "Transactions") {
                            NotificationToggle(
                                title: "New expense added",
                                icon: "plus.circle.fill",
                                isOn: $viewModel.newExpenseAdded
                            )

                            Divider().padding(.leading, 50)

                            NotificationToggle(
                                title: "Someone paid you",
                                icon: "dollarsign.circle.fill",
                                isOn: $viewModel.someonePaidYou
                            )
                        }

                        // Payment Reminders
                        SettingsGroup(title: "Payment Reminders") {
                            NotificationToggle(
                                title: "Upcoming payments",
                                icon: "bell.badge.fill",
                                isOn: $viewModel.paymentReminders
                            )

                            if viewModel.paymentReminders {
                                Divider().padding(.leading, 50)

                                HStack {
                                    Text("Remind me")
                                        .font(AppTypography.body())
                                    Spacer()
                                    Picker("", selection: $viewModel.reminderDaysBefore) {
                                        ForEach(1...7, id: \.self) { day in
                                            Text("\(day) days before").tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                            }
                        }

                        // Subscription Notifications
                        SettingsGroup(title: "Subscriptions") {
                            NotificationToggle(
                                title: "Subscription due soon",
                                icon: "calendar.badge.clock",
                                isOn: $viewModel.subscriptionDueSoon
                            )

                            if viewModel.subscriptionDueSoon {
                                Divider().padding(.leading, 50)

                                HStack {
                                    Text("Notify me")
                                        .font(AppTypography.body())
                                    Spacer()
                                    Picker("", selection: $viewModel.subscriptionDueDays) {
                                        ForEach(1...7, id: \.self) { day in
                                            Text("\(day) days before").tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                            }
                        }

                        // Summary Notifications
                        SettingsGroup(title: "Summaries") {
                            NotificationToggle(
                                title: "Weekly summary",
                                icon: "chart.bar.fill",
                                isOn: $viewModel.weeklySummary
                            )
                        }
                    }
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .alert("Enable Notifications", isPresented: $viewModel.showSystemSettingsPrompt) {
            Button("Open Settings") {
                viewModel.openSystemSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled at the system level. Open Settings to enable them.")
        }
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - Supporting Views

private struct SystemStatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: action) {
                Text(buttonTitle)
                    .font(AppTypography.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.buttonForeground)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(AppColors.buttonBackground)
                    )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct SettingsGroup<Content: View>: View {
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
        .padding(.horizontal)
    }
}

private struct NotificationToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 28)

            Text(title)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _, _ in
                    HapticManager.toggle()
                }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading...")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
