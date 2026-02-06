//
//  EditSubscriptionView.swift
//  Swiss Coin
//
//  Form for editing an existing subscription.
//

import CoreData
import SwiftUI

struct EditSubscriptionView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var amount: String
    @State private var cycle: String
    @State private var customCycleDays: Int
    @State private var startDate: Date
    @State private var nextBillingDate: Date
    @State private var isShared: Bool
    @State private var selectedCategory: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var notificationEnabled: Bool
    @State private var notificationDays: Int
    @State private var notes: String

    @State private var selectedMembers: Set<Person>
    @State private var showingMemberPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    let cycles = ["Weekly", "Monthly", "Yearly", "Custom"]
    let categories = ["Entertainment", "Productivity", "Utilities", "Health", "Food", "Transportation", "Education", "Other"]

    init(subscription: Subscription) {
        self.subscription = subscription
        _name = State(initialValue: subscription.name ?? "")
        _amount = State(initialValue: String(subscription.amount))
        _cycle = State(initialValue: subscription.cycle ?? "Monthly")
        _customCycleDays = State(initialValue: Int(subscription.customCycleDays))
        _startDate = State(initialValue: subscription.startDate ?? Date())
        _nextBillingDate = State(initialValue: subscription.nextBillingDate ?? Date())
        _isShared = State(initialValue: subscription.isShared)
        _selectedCategory = State(initialValue: subscription.category ?? "Entertainment")
        _selectedIcon = State(initialValue: subscription.iconName ?? "creditcard.fill")
        _selectedColor = State(initialValue: subscription.colorHex ?? "#007AFF")
        _notificationEnabled = State(initialValue: subscription.notificationEnabled)
        _notificationDays = State(initialValue: Int(subscription.notificationDaysBefore))
        _notes = State(initialValue: subscription.notes ?? "")
        // Exclude the current user from selectedMembers (they're added automatically on save)
        let allSubscribers = subscription.subscribers as? Set<Person> ?? []
        _selectedMembers = State(initialValue: allSubscribers.filter { !CurrentUser.isCurrentUser($0.id) })
    }

    private var canSave: Bool {
        let hasBasicInfo = !name.isEmpty && !amount.isEmpty && (Double(amount) ?? 0) > 0
        // Shared subscriptions must have at least one member
        if isShared {
            return hasBasicInfo && !selectedMembers.isEmpty
        }
        return hasBasicInfo
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                appearanceSection
                sharingSection
                remindersSection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary.ignoresSafeArea())
            .navigationTitle("Edit Subscription")
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
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Section Views

    private var basicInfoSection: some View {
        Section {
            TextField("Name (e.g., Netflix)", text: $name)
                .limitTextLength(to: ValidationLimits.maxNameLength, text: $name)

            HStack {
                Text(CurrencyFormatter.currencySymbol)
                    .foregroundColor(AppColors.textSecondary)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .limitTextLength(to: 12, text: $amount)
            }

            Picker("Billing Cycle", selection: $cycle) {
                ForEach(cycles, id: \.self) { Text($0) }
            }

            if cycle == "Custom" {
                Stepper("Every \(customCycleDays) days", value: $customCycleDays, in: 1...365)
            }

            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

            DatePicker("Next Billing", selection: $nextBillingDate, displayedComponents: .date)

            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0) }
            }
        } header: {
            Text("Subscription Details")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    private var appearanceSection: some View {
        Section {
            IconPickerRow(selectedIcon: $selectedIcon)
            ColorPickerRow(selectedColor: $selectedColor)
        } header: {
            Text("Appearance")
        }
        .listRowBackground(AppColors.cardBackground)
    }

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
                }
            }
        } header: {
            Text("Sharing")
        }
        .listRowBackground(AppColors.cardBackground)
    }

    private var memberChipsView: some View {
        let sortedMembers = Array(selectedMembers).sorted(by: { member1, member2 in
            let name1 = member1.name ?? ""
            let name2 = member2.name ?? ""
            return name1 < name2
        })
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(sortedMembers) { member in
                    MemberChip(person: member) {
                        HapticManager.tap()
                        selectedMembers.remove(member)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Payment Reminders", isOn: $notificationEnabled)
                .onChange(of: notificationEnabled) { _, _ in
                    HapticManager.toggle()
                }

            if notificationEnabled {
                Stepper("\(notificationDays) days before", value: $notificationDays, in: 1...14)
            }
        } header: {
            Text("Reminders")
        }
        .listRowBackground(AppColors.cardBackground)
    }

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

    private func saveSubscription() {
        HapticManager.save()

        subscription.name = name
        subscription.amount = Double(amount) ?? 0
        subscription.cycle = cycle
        subscription.customCycleDays = Int16(customCycleDays)
        subscription.startDate = startDate
        subscription.nextBillingDate = nextBillingDate
        subscription.isShared = isShared
        subscription.category = selectedCategory
        subscription.iconName = selectedIcon
        subscription.colorHex = selectedColor
        subscription.notificationEnabled = notificationEnabled
        subscription.notificationDaysBefore = Int16(notificationDays)
        subscription.notes = notes.isEmpty ? nil : notes

        // Update members
        // Remove old members
        if let existingMembers = subscription.subscribers as? Set<Person> {
            for member in existingMembers {
                subscription.removeFromSubscribers(member)
            }
        }

        // Add new members (including current user for accurate subscriber count)
        if isShared {
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            subscription.addToSubscribers(currentUser)
            for member in selectedMembers {
                subscription.addToSubscribers(member)
            }
        }

        do {
            try viewContext.save()

            // Reschedule notification based on updated settings
            if notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            } else {
                NotificationManager.shared.cancelSubscriptionReminder(for: subscription)
            }

            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save subscription: \(error.localizedDescription)"
            showingError = true
        }
    }
}
