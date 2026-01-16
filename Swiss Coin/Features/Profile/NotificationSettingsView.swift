//
//  NotificationSettingsView.swift
//  Swiss Coin
//
//  View for managing notification preferences with Supabase integration.
//  Provides granular control over all notification types.
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
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var lastSyncedAt: Date?
    @Published var systemNotificationsEnabled: Bool = true
    @Published var showSystemSettingsPrompt: Bool = false

    // MARK: - Private Properties

    private let supabase = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var saveTask: Task<Void, Never>?

    // MARK: - AppStorage (offline fallback)

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
        errorMessage = nil

        // Check system notification permission
        await checkSystemNotificationStatus()

        do {
            let settings = try await supabase.getNotificationSettingsComplete()

            // Update published properties
            allNotificationsEnabled = settings.allNotificationsEnabled
            newExpenseAdded = settings.newExpenseAdded
            expenseModified = settings.expenseModified
            someonePaidYou = settings.someonePaidYou
            paymentReminders = settings.paymentReminders
            reminderDaysBefore = settings.reminderDaysBefore
            subscriptionDueSoon = settings.subscriptionDueSoon
            subscriptionDueDays = settings.subscriptionDueDays
            subscriptionOverdue = settings.subscriptionOverdue
            settlementReceived = settings.settlementReceived
            settlementSent = settings.settlementSent
            addedToGroup = settings.addedToGroup
            groupExpenseAdded = settings.groupExpenseAdded
            newMessage = settings.newMessage
            weeklySummary = settings.weeklySummary
            monthlyReport = settings.monthlyReport
            quietHoursEnabled = settings.quietHoursEnabled

            // Parse quiet hours times
            if let startStr = settings.quietHoursStart {
                quietHoursStart = parseTime(startStr) ?? quietHoursStart
            }
            if let endStr = settings.quietHoursEnd {
                quietHoursEnd = parseTime(endStr) ?? quietHoursEnd
            }

            syncToLocalStorage()
            lastSyncedAt = Date()
        } catch {
            loadFromLocalStorage()

            if case SupabaseError.notAuthenticated = error {
                // Silently use local settings
            } else {
                errorMessage = "Failed to load settings: \(error.localizedDescription)"
                showError = true
            }
        }

        isLoading = false
    }

    func saveSettings() async {
        guard supabase.currentUserId != nil else { return }

        isSaving = true

        var update = NotificationSettingsUpdate()
        update.allNotificationsEnabled = allNotificationsEnabled
        update.newExpenseAdded = newExpenseAdded
        update.expenseModified = expenseModified
        update.someonePaidYou = someonePaidYou
        update.paymentReminders = paymentReminders
        update.reminderDaysBefore = reminderDaysBefore
        update.subscriptionDueSoon = subscriptionDueSoon
        update.subscriptionDueDays = subscriptionDueDays
        update.subscriptionOverdue = subscriptionOverdue
        update.settlementReceived = settlementReceived
        update.settlementSent = settlementSent
        update.addedToGroup = addedToGroup
        update.groupExpenseAdded = groupExpenseAdded
        update.newMessage = newMessage
        update.weeklySummary = weeklySummary
        update.monthlyReport = monthlyReport
        update.quietHoursEnabled = quietHoursEnabled
        update.quietHoursStart = formatTime(quietHoursStart)
        update.quietHoursEnd = formatTime(quietHoursEnd)

        do {
            try await supabase.updateNotificationSettingsComplete(update)
            syncToLocalStorage()
            lastSyncedAt = Date()
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showError = true
        }

        isSaving = false
    }

    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            systemNotificationsEnabled = granted

            if !granted {
                showSystemSettingsPrompt = true
            }
        } catch {
            systemNotificationsEnabled = false
        }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func checkSystemNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemNotificationsEnabled = settings.authorizationStatus == .authorized
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
        // Combine all publishers for auto-save
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
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.triggerSave()
            }
            .store(in: &cancellables)
    }

    private func triggerSave() {
        saveTask?.cancel()
        saveTask = Task {
            await saveSettings()
        }
    }

    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return calendar.date(from: components)
        }
        return nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - View

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            // System Notification Status
            if !viewModel.systemNotificationsEnabled {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.warning)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Notifications Disabled")
                                .font(AppTypography.subheadlineMedium())

                            Text("Enable notifications in Settings to receive alerts.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Button("Enable") {
                            viewModel.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }

            // Sync Status
            if viewModel.isSaving {
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing...")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            // Master Toggle
            Section {
                Toggle(isOn: $viewModel.allNotificationsEnabled) {
                    Label("All Notifications", systemImage: "bell.fill")
                }
                .onChange(of: viewModel.allNotificationsEnabled) { _, _ in
                    HapticManager.toggle()
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

            // Sync Info Section
            if let lastSynced = viewModel.lastSyncedAt {
                Section {
                    HStack {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(AppColors.positive)
                        Text("Last synced: \(lastSynced.formatted(date: .omitted, time: .shortened))")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task { await viewModel.loadSettings() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text("Loading notifications...")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(.white)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color(UIColor.systemGray5))
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
