//
//  EditSubscriptionPaymentView.swift
//  Swiss Coin
//
//  Edit form for an existing subscription payment.
//  Mirrors RecordSubscriptionPaymentView structure but updates in place.
//

import CoreData
import SwiftUI

struct EditSubscriptionPaymentView: View {
    @ObservedObject var payment: SubscriptionPayment
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var selectedPayer: Person?
    @State private var amount: String
    @State private var date: Date
    @State private var note: String
    @State private var showingPayerPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAmountValid = true

    init(payment: SubscriptionPayment) {
        self.payment = payment
        _amount = State(initialValue: String(payment.amount))
        _date = State(initialValue: payment.date ?? Date())
        _note = State(initialValue: payment.note ?? "")
    }

    private var canSave: Bool {
        selectedPayer != nil && isAmountValid && parsedAmount > 0
    }

    private var parsedAmount: Double {
        Double(amount.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var members: [Person] {
        let subscribersSet = payment.subscription?.subscribers as? Set<Person> ?? []
        return Array(subscribersSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var subscriberCount: Int {
        payment.subscription?.subscriberCount ?? 1
    }

    private func validateAmount(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard let numValue = Double(trimmed) else { return false }
        guard numValue > 0 && numValue <= 999_999_999.99 else { return false }
        if trimmed.contains(".") {
            let parts = trimmed.split(separator: ".")
            if parts.count == 2 && parts[1].count > 2 {
                return false
            }
        }
        return true
    }

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
        }
        return result
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
                                    let sanitized = sanitizeAmountInput(newValue)
                                    if sanitized != newValue {
                                        amount = sanitized
                                    }
                                    isAmountValid = sanitized.isEmpty || validateAmount(sanitized)
                                }
                        }

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
                    let memberCount = max(1, subscriberCount)
                    let splitAmount = paymentAmount / Double(memberCount)

                    HStack {
                        Text("Total")
                        Spacer()
                        Text(CurrencyFormatter.format(paymentAmount))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Split \(subscriberCount) ways")
                        Spacer()
                        (Text(CurrencyFormatter.format(splitAmount)).fontWeight(.bold) + Text(" each"))
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("Split Preview")
                        .font(AppTypography.labelLarge())
                }
            }
            .navigationTitle("Edit Payment")
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
                        saveChanges()
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
                selectedPayer = payment.payer
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

    private func saveChanges() {
        HapticManager.save()
        payment.amount = parsedAmount
        payment.date = date
        payment.note = note.isEmpty ? nil : note
        payment.payer = selectedPayer

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
}
