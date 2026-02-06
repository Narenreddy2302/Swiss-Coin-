//
//  AddSubscriptionView.swift
//  Swiss Coin
//
//  Clean, minimal subscription creation form matching Apple's standard patterns.
//

import CoreData
import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let defaultIsShared: Bool

    // MARK: - State
    @State private var name = ""
    @State private var amount = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var selectedCategory = "Entertainment"
    @State private var isShared = false
    @State private var selectedMembers: Set<Person> = []
    @State private var startDate = Date()
    @State private var notificationEnabled = true
    @State private var notificationDays = 3
    @State private var notes = ""

    // MARK: - UI State
    @State private var showingMemberPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    let categories = ["Entertainment", "Productivity", "Utilities", "Health", "Food", "Transportation", "Education", "Other"]

    init(isSharedDefault: Bool = false) {
        self.defaultIsShared = isSharedDefault
        _isShared = State(initialValue: isSharedDefault)
    }

    // MARK: - Validation
    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountValue = Double(amount) ?? 0
        let hasBasicInfo = !trimmedName.isEmpty && amountValue > 0
        if isShared {
            return hasBasicInfo && !selectedMembers.isEmpty
        }
        return hasBasicInfo
    }

    private var monthlyCost: Double {
        let value = Double(amount) ?? 0
        return cycle.monthlyEquivalent(for: value)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                sharingSection
                scheduleSection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary.ignoresSafeArea())
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSubscription()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingMemberPicker) {
                MemberPickerView(selectedMembers: $selectedMembers)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        Section {
            TextField("Name (e.g., Netflix, Spotify)", text: $name)
                .limitTextLength(to: ValidationLimits.maxNameLength, text: $name)

            HStack {
                Text(CurrencyFormatter.currencySymbol)
                    .foregroundColor(AppColors.textSecondary)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .limitTextLength(to: 12, text: $amount)
            }

            Picker("Billing Cycle", selection: $cycle) {
                ForEach(BillingCycle.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }

            if cycle != .monthly, let value = Double(amount), value > 0 {
                HStack {
                    Text("Monthly equivalent")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("~\(CurrencyFormatter.format(monthlyCost))")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Label(category, systemImage: iconFor(category))
                        .tag(category)
                }
            }
        } header: {
            Text("Details")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    // MARK: - Sharing Section
    private var sharingSection: some View {
        Section {
            Toggle("Shared Subscription", isOn: $isShared)
                .onChange(of: isShared) { _, newValue in
                    HapticManager.toggle()
                    if !newValue {
                        selectedMembers.removeAll()
                    }
                }

            if isShared {
                Button {
                    HapticManager.tap()
                    showingMemberPicker = true
                } label: {
                    HStack {
                        Text("Members")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text("\(selectedMembers.count) selected")
                            .foregroundColor(AppColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if !selectedMembers.isEmpty {
                    memberChipsView

                    if let amountValue = Double(amount), amountValue > 0 {
                        HStack {
                            Text("Each person pays")
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text(CurrencyFormatter.format(amountValue / Double(selectedMembers.count + 1)))
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        } header: {
            Text("Sharing")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    private var memberChipsView: some View {
        let sortedMembers = Array(selectedMembers).sorted { ($0.name ?? "") < ($1.name ?? "") }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(sortedMembers) { member in
                    MemberChip(person: member) {
                        HapticManager.tap()
                        withAnimation(AppAnimation.quick) {
                            selectedMembers.remove(member)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: - Schedule Section
    private var scheduleSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

            Toggle("Payment Reminders", isOn: $notificationEnabled)
                .onChange(of: notificationEnabled) { _, _ in
                    HapticManager.toggle()
                }

            if notificationEnabled {
                Stepper("\(notificationDays) days before", value: $notificationDays, in: 1...14)
            }
        } header: {
            Text("Schedule")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(height: 80)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .limitTextLength(to: ValidationLimits.maxNoteLength, text: $notes)
        } header: {
            Text("Notes")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    // MARK: - Helpers

    private func iconFor(_ category: String) -> String {
        switch category {
        case "Entertainment": return "film.fill"
        case "Productivity": return "briefcase.fill"
        case "Utilities": return "bolt.fill"
        case "Health": return "heart.fill"
        case "Food": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Education": return "book.fill"
        default: return "creditcard.fill"
        }
    }

    private var colorHexForCategory: String {
        switch selectedCategory {
        case "Entertainment": return "#FF2D55"
        case "Productivity": return "#007AFF"
        case "Utilities": return "#FF9500"
        case "Health": return "#34C759"
        case "Food": return "#FF3B30"
        case "Transportation": return "#5856D6"
        case "Education": return "#5AC8FA"
        default: return "#8E8E93"
        }
    }

    // MARK: - Save

    private func saveSubscription() {
        HapticManager.save()

        let subscription = Subscription(context: viewContext)
        subscription.id = UUID()
        subscription.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        subscription.amount = Double(amount) ?? 0
        subscription.cycle = cycle.rawValue
        subscription.startDate = startDate
        subscription.nextBillingDate = calculateNextBillingDate()
        subscription.isShared = isShared
        subscription.isActive = true
        subscription.category = selectedCategory
        subscription.iconName = iconFor(selectedCategory)
        subscription.notificationEnabled = notificationEnabled
        subscription.notificationDaysBefore = Int16(notificationDays)
        subscription.notes = notes.isEmpty ? nil : notes
        subscription.colorHex = colorHexForCategory

        if isShared {
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            subscription.addToSubscribers(currentUser)
            for member in selectedMembers {
                subscription.addToSubscribers(member)
            }
        }

        do {
            try viewContext.save()

            if notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }

            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save subscription"
            showingError = true
        }
    }

    private func calculateNextBillingDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var nextDate = startDate

        while nextDate <= now {
            switch cycle {
            case .weekly:
                nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            case .yearly:
                nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate) ?? nextDate
            case .custom:
                nextDate = calendar.date(byAdding: .day, value: 30, to: nextDate) ?? nextDate
            }
        }

        return nextDate
    }
}

// MARK: - Billing Cycle Enum

enum BillingCycle: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }

    func monthlyEquivalent(for amount: Double) -> Double {
        switch self {
        case .weekly:
            return amount * 4.33
        case .monthly:
            return amount
        case .yearly:
            return amount / 12.0
        case .custom:
            return amount
        }
    }
}
