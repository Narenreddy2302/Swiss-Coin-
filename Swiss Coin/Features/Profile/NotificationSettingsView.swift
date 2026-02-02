//
//  NotificationSettingsView.swift
//  Swiss Coin
//
//  View for managing notification preferences.
//  All settings are stored locally via AppStorage.
//

import Combine
import SwiftUI
import UserNotifications

// MARK: - ViewModel

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    // Master Toggle
    @Published var allNotificationsEnabled: Bool = true

    // Transaction Notifications
    @Published var newExpenseAdded: Bool = true
    @Published var expenseModified: Bool = true
    @Published var someonePaidYou: Bool = true

    // Reminder Notifications
    @Published var paymentReminders: Bool = true
    @Published var reminderDaysBefore: Int = 3

    // Subscription Notifications
    @Published var subscriptionDueSoon: Bool = true
    @Published var subscriptionDueDays: Int = 3
    @Published var subscriptionOverdue: Bool = true

    // Settlement Notifications
    @Published var settlementReceived: Bool = true
    @Published var settlementSent: Bool = true

    // Group Notifications
    @Published var addedToGroup: Bool = true
    @Published var groupExpenseAdded: Bool = true

    // Chat Notifications
    @Published var newMessage: Bool = true

    // Summary Notifications
    @Published var weeklySummary: Bool = true
    @Published var monthlyReport: Bool = false

    // Quiet Hours
    @Published var quietHoursEnabled: Bool = false
    @Published var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    // State
    @Published var isLoading: Bool = false
    @Published var systemNotificationsEnabled: Bool = true
    @Published var showSystemSettingsPrompt: Bool = false
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - AppStorage (local persistence)

    @AppStorage("notifications_enabled") private var storedAllNotifications = true
    @AppStorage("notify_new_expense") private var storedNewExpense = true
    @AppStorage("notify_expense_modified") private var storedExpenseModified = true
    @AppStorage("notify_someone_paid") private var storedSomeonePaid = true
    @AppStorage("notify_payment_reminders") private var storedPaymentReminders = true
    @AppStorage("reminder_days_before") private var storedReminderDays = 3
    @AppStorage("notify_subscription_due") private var storedSubscriptionDue = true
    @AppStorage("subscription_due_days") private var storedSubscriptionDays = 3
    @AppStorage("notify_subscription_overdue") private var storedSubscriptionOverdue = true
    @AppStorage("notify_settlement_received") private var storedSettlementReceived = true
    @AppStorage("notify_settlement_sent") private var storedSettlementSent = true
    @AppStorage("notify_added_to_group") private var storedAddedToGroup = true
    @AppStorage("notify_group_expense") private var storedGroupExpense = true
    @AppStorage("notify_new_message") private var storedNewMessage = true
    @AppStorage("notify_weekly_summary") private var storedWeeklySummary = true
    @AppStorage("notify_monthly_report") private var storedMonthlyReport = false
    @AppStorage("quiet_hours_enabled") private var storedQuietHoursEnabled = false

    // MARK: - Init

    init() {
        loadFromLocalStorage()
        setupAutoSave()
    }

    // MARK: - Public Methods

    func loadSettings() async {
        isLoading = true

        // Check system notification permission via NotificationManager
        await NotificationManager.shared.refreshPermissionStatus()
        let status = NotificationManager.shared.permissionStatus
        permissionStatus = status
        systemNotificationsEnabled = status == .authorized

        // Load from local storage
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

    // MARK: - Private Methods

    private func checkSystemNotificationStatus() async {
        await NotificationManager.shared.refreshPermissionStatus()
        let status = NotificationManager.shared.permissionStatus
        permissionStatus = status
        systemNotificationsEnabled = status == .authorized
    }

    private func loadFromLocalStorage() {
        allNotificationsEnabled = storedAllNotifications
        newExpenseAdded = storedNewExpense
        expenseModified = storedExpenseModified
        someonePaidYou = storedSomeonePaid
        paymentReminders = storedPaymentReminders
        reminderDaysBefore = storedReminderDays
        subscriptionDueSoon = storedSubscriptionDue
        subscriptionDueDays = storedSubscriptionDays
        subscriptionOverdue = storedSubscriptionOverdue
        settlementReceived = storedSettlementReceived
        settlementSent = storedSettlementSent
        addedToGroup = storedAddedToGroup
        groupExpenseAdded = storedGroupExpense
        newMessage = storedNewMessage
        weeklySummary = storedWeeklySummary
        monthlyReport = storedMonthlyReport
        quietHoursEnabled = storedQuietHoursEnabled
    }

    private func syncToLocalStorage() {
        storedAllNotifications = allNotificationsEnabled
        storedNewExpense = newExpenseAdded
        storedExpenseModified = expenseModified
        storedSomeonePaid = someonePaidYou
        storedPaymentReminders = paymentReminders
        storedReminderDays = reminderDaysBefore
        storedSubscriptionDue = subscriptionDueSoon
        storedSubscriptionDays = subscriptionDueDays
        storedSubscriptionOverdue = subscriptionOverdue
        storedSettlementReceived = settlementReceived
        storedSettlementSent = settlementSent
        storedAddedToGroup = addedToGroup
        storedGroupExpense = groupExpenseAdded
        storedNewMessage = newMessage
        storedWeeklySummary = weeklySummary
        storedMonthlyReport = monthlyReport
        storedQuietHoursEnabled = quietHoursEnabled
    }

    private func setupAutoSave() {
        // Combine all publishers for auto-save to local storage
        let boolPublishers = Publishers.MergeMany([
            $allNotificationsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $newExpenseAdded.map { _ in () }.eraseToAnyPublisher(),
            $expenseModified.map { _ in () }.eraseToAnyPublisher(),
            $someonePaidYou.map { _ in () }.eraseToAnyPublisher(),
            $paymentReminders.map { _ in () }.eraseToAnyPublisher(),
            $subscriptionDueSoon.map { _ in () }.eraseToAnyPublisher(),
            $subscriptionOverdue.map { _ in () }.eraseToAnyPublisher(),
            $settlementReceived.map { _ in () }.eraseToAnyPublisher(),
            $settlementSent.map { _ in () }.eraseToAnyPublisher(),
            $addedToGroup.map { _ in () }.eraseToAnyPublisher(),
            $groupExpenseAdded.map { _ in () }.eraseToAnyPublisher(),
            $newMessage.map { _ in () }.eraseToAnyPublisher(),
            $weeklySummary.map { _ in () }.eraseToAnyPublisher(),
            $monthlyReport.map { _ in () }.eraseToAnyPublisher(),
            $quietHoursEnabled.map { _ in () }.eraseToAnyPublisher()
        ])

        let intPublishers = Publishers.Merge(
            $reminderDaysBefore.map { _ in () },
            $subscriptionDueDays.map { _ in () }
        )

        let datePublishers = Publishers.Merge(
            $quietHoursStart.map { _ in () },
            $quietHoursEnd.map { _ in () }
        )

        Publishers.Merge3(boolPublishers, intPublishers.eraseToAnyPublisher(), datePublishers.eraseToAnyPublisher())
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
        Form {
            // System Notification Status
            if viewModel.permissionStatus == .denied {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.warning)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Notifications Blocked")
                                .font(AppTypography.subheadlineMedium())

                            Text("Notifications are disabled in System Settings. Tap to open Settings and enable them.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Button("Settings") {
                            viewModel.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Notifications are blocked. Tap Settings to enable them.")
                }
            } else if viewModel.permissionStatus == .notDetermined {
                Section {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(AppColors.accent)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Enable Notifications")
                                .font(AppTypography.subheadlineMedium())

                            Text("Allow Swiss Coin to send you reminders about upcoming payments.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Button("Enable") {
                            Task {
                                await viewModel.requestNotificationPermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }

            // Master Toggle
            Section {
                Toggle(isOn: $viewModel.allNotificationsEnabled) {
                    Label("All Notifications", systemImage: "bell.fill")
                }
                .onChange(of: viewModel.allNotificationsEnabled) { _, newValue in
                    HapticManager.toggle()
                    if newValue && viewModel.permissionStatus == .notDetermined {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    }
                }
            } footer: {
                Text("Turn off to disable all notifications from Swiss Coin.")
                    .font(AppTypography.caption())
            }

            if viewModel.allNotificationsEnabled {
                // Transaction Notifications
                Section {
                    NotificationToggle(
                        title: "New expense added",
                        icon: "plus.circle.fill",
                        isOn: $viewModel.newExpenseAdded
                    )

                    NotificationToggle(
                        title: "Expense modified",
                        icon: "pencil.circle.fill",
                        isOn: $viewModel.expenseModified
                    )

                    NotificationToggle(
                        title: "Someone paid you",
                        icon: "dollarsign.circle.fill",
                        isOn: $viewModel.someonePaidYou
                    )
                } header: {
                    Label("Transactions", systemImage: "creditcard.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Payment Reminders
                Section {
                    NotificationToggle(
                        title: "Payment reminders",
                        icon: "bell.badge.fill",
                        isOn: $viewModel.paymentReminders
                    )

                    if viewModel.paymentReminders {
                        Stepper(
                            "\(viewModel.reminderDaysBefore) days before due",
                            value: $viewModel.reminderDaysBefore,
                            in: 1...14
                        )
                    }
                } header: {
                    Label("Reminders", systemImage: "bell.badge.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Subscription Notifications
                Section {
                    NotificationToggle(
                        title: "Subscription due soon",
                        icon: "calendar.badge.clock",
                        isOn: $viewModel.subscriptionDueSoon
                    )

                    if viewModel.subscriptionDueSoon {
                        Stepper(
                            "\(viewModel.subscriptionDueDays) days before billing",
                            value: $viewModel.subscriptionDueDays,
                            in: 1...14
                        )
                    }

                    NotificationToggle(
                        title: "Subscription overdue",
                        icon: "exclamationmark.circle.fill",
                        isOn: $viewModel.subscriptionOverdue
                    )
                } header: {
                    Label("Subscriptions", systemImage: "repeat.circle.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Settlement Notifications
                Section {
                    NotificationToggle(
                        title: "Settlement received",
                        icon: "arrow.down.circle.fill",
                        isOn: $viewModel.settlementReceived
                    )

                    NotificationToggle(
                        title: "Settlement sent",
                        icon: "arrow.up.circle.fill",
                        isOn: $viewModel.settlementSent
                    )
                } header: {
                    Label("Settlements", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Group Notifications
                Section {
                    NotificationToggle(
                        title: "Added to group",
                        icon: "person.badge.plus.fill",
                        isOn: $viewModel.addedToGroup
                    )

                    NotificationToggle(
                        title: "Group expense added",
                        icon: "person.3.fill",
                        isOn: $viewModel.groupExpenseAdded
                    )
                } header: {
                    Label("Groups", systemImage: "person.3.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Chat Notifications
                Section {
                    NotificationToggle(
                        title: "New messages",
                        icon: "message.fill",
                        isOn: $viewModel.newMessage
                    )
                } header: {
                    Label("Messages", systemImage: "message.fill")
                        .font(AppTypography.subheadlineMedium())
                }

                // Summary Notifications
                Section {
                    NotificationToggle(
                        title: "Weekly summary",
                        icon: "chart.bar.fill",
                        isOn: $viewModel.weeklySummary
                    )

                    NotificationToggle(
                        title: "Monthly report",
                        icon: "chart.pie.fill",
                        isOn: $viewModel.monthlyReport
                    )
                } header: {
                    Label("Summaries", systemImage: "chart.bar.fill")
                        .font(AppTypography.subheadlineMedium())
                } footer: {
                    Text("Get periodic summaries of your spending and balances.")
                        .font(AppTypography.caption())
                }

                // Quiet Hours
                Section {
                    NotificationToggle(
                        title: "Quiet Hours",
                        icon: "moon.fill",
                        isOn: $viewModel.quietHoursEnabled
                    )

                    if viewModel.quietHoursEnabled {
                        DatePicker(
                            "Start",
                            selection: $viewModel.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )

                        DatePicker(
                            "End",
                            selection: $viewModel.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Label("Quiet Hours", systemImage: "moon.fill")
                        .font(AppTypography.subheadlineMedium())
                } footer: {
                    if viewModel.quietHoursEnabled {
                        Text("Notifications will be silenced during quiet hours.")
                            .font(AppTypography.caption())
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                NotificationLoadingOverlay()
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

// MARK: - Notification Toggle

private struct NotificationToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 20)

                Text(title)
            }
        }
        .onChange(of: isOn) { _, _ in
            HapticManager.toggle()
        }
    }
}

// MARK: - Loading Overlay

private struct NotificationLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color(.label).opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading notifications...")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackgroundElevated)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
