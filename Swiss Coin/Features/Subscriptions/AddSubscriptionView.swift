//
//  AddSubscriptionView.swift
//  Swiss Coin
//
//  Form for creating a new subscription.
//

import CoreData
import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let isSharedDefault: Bool

    @State private var name = ""
    @State private var amount = ""
    @State private var cycle = "Monthly"
    @State private var customCycleDays = 30
    @State private var startDate = Date()
    @State private var isShared: Bool
    @State private var selectedCategory = "Entertainment"
    @State private var selectedIcon = "creditcard.fill"
    @State private var selectedColor = "#007AFF"
    @State private var notificationEnabled = true
    @State private var notificationDays = 3
    @State private var notes = ""

    // For shared subscriptions
    @State private var selectedMembers: Set<Person> = []
    @State private var showingMemberPicker = false
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false

    let cycles = ["Weekly", "Monthly", "Yearly", "Custom"]
    let categories = ["Entertainment", "Productivity", "Utilities", "Health", "Food", "Transportation", "Education", "Other"]

    init(isSharedDefault: Bool = false) {
        self.isSharedDefault = isSharedDefault
        _isShared = State(initialValue: isSharedDefault)
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
                } footer: {
                    if isShared {
                        Text("Split the cost with friends and family. Each person will owe their share.")
                            .font(AppTypography.caption())
                    }
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
        }
    }

    private func saveSubscription() {
        HapticManager.save()

        let subscription = Subscription(context: viewContext)
        subscription.id = UUID()
        subscription.name = name
        subscription.amount = Double(amount) ?? 0
        subscription.cycle = cycle
        subscription.customCycleDays = Int16(customCycleDays)
        subscription.startDate = startDate
        subscription.nextBillingDate = calculateNextBillingDate()
        subscription.isShared = isShared
        subscription.isActive = true
        subscription.category = selectedCategory
        subscription.iconName = selectedIcon
        subscription.colorHex = selectedColor
        subscription.notificationEnabled = notificationEnabled
        subscription.notificationDaysBefore = Int16(notificationDays)
        subscription.notes = notes.isEmpty ? nil : notes

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

    private func calculateNextBillingDate() -> Date {
        let calendar = Calendar.current

        switch cycle {
        case "Weekly":
            return calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case "Monthly":
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case "Yearly":
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case "Custom":
            return calendar.date(byAdding: .day, value: customCycleDays, to: startDate) ?? startDate
        default:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        }
    }
}

// MARK: - Member Chip

struct MemberChip: View {
    let person: Person
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color(hex: person.colorHex ?? "#808080").opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: person.colorHex ?? "#808080"))
                )

            Text(person.firstName)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(AppColors.cardBackground)
        )
    }
}
