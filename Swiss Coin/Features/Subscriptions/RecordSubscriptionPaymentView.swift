//
//  RecordSubscriptionPaymentView.swift
//  Swiss Coin
//
//  View for recording when someone pays for a shared subscription billing cycle.
//

import CoreData
import SwiftUI

struct RecordSubscriptionPaymentView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var selectedPayer: Person?
    @State private var amount: String
    @State private var date = Date()
    @State private var note = ""
    @State private var showingPayerPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAmountValid = true

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    init(subscription: Subscription) {
        self.subscription = subscription
        _amount = State(initialValue: String(subscription.amount))
    }

    private var canSave: Bool {
        selectedPayer != nil && isAmountValid && parsedAmount > 0
    }

    /// Parsed amount value, returns 0 if invalid
    private var parsedAmount: Double {
        Double(amount.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    /// Validates the amount input and returns whether it's valid
    private func validateAmount(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Empty is invalid but we don't show error for empty state
        guard !trimmed.isEmpty else { return false }

        // Must be a valid number
        guard let numValue = Double(trimmed) else { return false }

        // Must be positive and within reasonable bounds
        guard numValue > 0 && numValue <= 999_999_999.99 else { return false }

        // Check for reasonable decimal places (max 2)
        if trimmed.contains(".") {
            let parts = trimmed.split(separator: ".")
            if parts.count == 2 && parts[1].count > 2 {
                return false
            }
        }

        return true
    }

    /// Sanitizes amount input to only allow valid numeric characters
    private func sanitizeAmountInput(_ value: String) -> String {
        var result = ""
        var hasDecimal = false

        for char in value {
            if char.isNumber {
                result.append(char)
            } else if char == "." && !hasDecimal {
                hasDecimal = true
                result.append(char)
            }
            // Ignore any other characters
        }

        return result
    }

    private var members: [Person] {
        let subscribersSet = subscription.subscribers as? Set<Person> ?? []
        return Array(subscribersSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Payer Selection
                Section {
                    Button {
                        HapticManager.tap()
                        showingPayerPicker = true
                    } label: {
                        HStack {
                            Text("Who Paid?")
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if let payer = selectedPayer {
                                HStack(spacing: Spacing.sm) {
                                    Circle()
                                        .fill(Color(hex: payer.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.3))
                                        .frame(width: IconSize.lg, height: IconSize.lg)
                                        .overlay(
                                            Text(payer.initials)
                                                .font(AppTypography.labelSmall())
                                                .foregroundColor(Color(hex: payer.colorHex ?? AppColors.defaultAvatarColorHex))
                                        )

                                    Text(CurrentUser.isCurrentUser(payer.id) ? "You" : payer.firstName)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            } else {
                                Text("Select")
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: IconSize.sm, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                } header: {
                    Text("Payment Details")
                        .font(AppTypography.labelLarge())
                }

                // Amount
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(CurrencyFormatter.currencySymbol)
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .onChange(of: amount) { _, newValue in
                                    // Sanitize input to only allow valid numeric characters
                                    let sanitized = sanitizeAmountInput(newValue)
                                    if sanitized != newValue {
                                        amount = sanitized
                                    }
                                    // Validate and update state
                                    isAmountValid = sanitized.isEmpty || validateAmount(sanitized)
                                }
                        }

                        // Show validation error feedback
                        if !isAmountValid && !amount.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: IconSize.xs))
                                Text("Please enter a valid amount")
                                    .font(AppTypography.caption())
                            }
                            .foregroundColor(AppColors.negative)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Amount")
                        .font(AppTypography.labelLarge())
                }

                // Note
                Section {
                    TextField("Add a note (optional)", text: $note)
                        .limitTextLength(to: ValidationLimits.maxNoteLength, text: $note)
                } header: {
                    Text("Note")
                        .font(AppTypography.labelLarge())
                }

                // Split Preview
                Section {
                    let paymentAmount = Double(amount) ?? 0
                    let memberCount = max(1, subscription.subscriberCount)
                    let splitAmount = paymentAmount / Double(memberCount)

                    HStack {
                        Text("Total")
                        Spacer()
                        Text(CurrencyFormatter.format(paymentAmount))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Split \(subscription.subscriberCount) ways")
                        Spacer()
                        (Text(CurrencyFormatter.format(splitAmount)).fontWeight(.bold) + Text(" each"))
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("Split Preview")
                        .font(AppTypography.labelLarge())
                }
            }
            .navigationTitle("Record Payment")
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
                        savePayment()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPayerPicker) {
                PayerPickerView(
                    selectedPayer: $selectedPayer,
                    members: members,
                    viewContext: viewContext
                )
            }
            .onAppear {
                // Default to current user as payer
                selectedPayer = CurrentUser.getOrCreate(in: viewContext)
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

    private func savePayment() {
        HapticManager.save()

        // Capture all values at the start of save operation to prevent race conditions
        // The nextBillingDate is read once and used consistently throughout
        let capturedNextBillingDate = subscription.nextBillingDate
        let billingPeriodStart = capturedNextBillingDate ?? date

        // Calculate the new next billing date based on captured state
        let newNextBillingDate = subscription.calculateNextBillingDate(from: date)

        let payment = SubscriptionPayment(context: viewContext)
        payment.id = UUID()
        payment.amount = Double(amount) ?? 0
        payment.date = date
        payment.note = note.isEmpty ? nil : note
        payment.payer = selectedPayer
        payment.subscription = subscription
        payment.billingPeriodStart = billingPeriodStart
        payment.billingPeriodEnd = newNextBillingDate

        // Update next billing date after creating payment with captured values
        subscription.nextBillingDate = newNextBillingDate

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save payment: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Payer Picker View

struct PayerPickerView: View {
    @Binding var selectedPayer: Person?
    let members: [Person]
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current User Option
                Section {
                    Button {
                        HapticManager.selectionChanged()
                        selectedPayer = CurrentUser.getOrCreate(in: viewContext)
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: CurrentUser.defaultColorHex).opacity(0.3))
                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                .overlay(
                                    Text(CurrentUser.initials)
                                        .font(AppTypography.labelDefault())
                                        .foregroundColor(Color(hex: CurrentUser.defaultColorHex))
                                )

                            Text("You")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if CurrentUser.isCurrentUser(selectedPayer?.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }

                // Members
                Section {
                    ForEach(members) { member in
                        Button {
                            HapticManager.selectionChanged()
                            selectedPayer = member
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: member.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.3))
                                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                    .overlay(
                                        Text(member.initials)
                                            .font(AppTypography.labelDefault())
                                            .foregroundColor(Color(hex: member.colorHex ?? AppColors.defaultAvatarColorHex))
                                    )

                                Text(member.displayName)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                if selectedPayer?.id == member.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Members")
                        .font(AppTypography.labelLarge())
                }
            }
            .navigationTitle("Who Paid?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
