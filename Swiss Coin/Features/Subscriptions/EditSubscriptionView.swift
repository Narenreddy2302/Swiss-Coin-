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
        _selectedMembers = State(initialValue: subscription.subscribers as? Set<Person> ?? [])
    }

    private var canSave: Bool {
        !name.isEmpty && !amount.isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section {
                    TextField("Name (e.g., Netflix)", text: $name)

                    HStack {
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
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
                        .font(AppTypography.subheadlineMedium())
                }

                // Appearance Section
                Section {
                    IconPickerRow(selectedIcon: $selectedIcon)

                    ColorPickerRow(selectedColor: $selectedColor)
                } header: {
                    Text("Appearance")
                        .font(AppTypography.subheadlineMedium())
                }

                // Shared Toggle Section
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
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.sm) {
                                    ForEach(Array(selectedMembers).sorted { ($0.name ?? "") < ($1.name ?? "") }) { member in
                                        MemberChip(person: member) {
                                            HapticManager.tap()
                                            selectedMembers.remove(member)
                                        }
                                    }
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                        }
                    }
                } header: {
                    Text("Sharing")
                        .font(AppTypography.subheadlineMedium())
                }

                // Notifications Section
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
                        .font(AppTypography.subheadlineMedium())
                }

                // Notes Section
                Section {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                } header: {
                    Text("Notes (Optional)")
                        .font(AppTypography.subheadlineMedium())
                }
            }
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
        }
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

        // Add new members
        if isShared {
            for member in selectedMembers {
                subscription.addToSubscribers(member)
            }
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving subscription: \(error)")
        }
    }
}
