//
//  TransactionEditView.swift
//  Swiss Coin
//
//  Edit view for modifying an existing transaction's basic details.
//

import CoreData
import SwiftUI

struct TransactionEditView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // Editable fields — initialized from the transaction
    @State private var title: String
    @State private var amount: String
    @State private var date: Date
    @State private var selectedPayer: Person?

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    // Fetch all people for the payer picker
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    private var otherPeople: [Person] {
        people.filter { !CurrentUser.isCurrentUser($0.id) }
    }

    // MARK: - Init

    init(transaction: FinancialTransaction) {
        self.transaction = transaction
        _title = State(initialValue: transaction.title ?? "")
        _amount = State(initialValue: String(format: "%.2f", transaction.amount))
        _date = State(initialValue: transaction.date ?? Date())
        _selectedPayer = State(initialValue: transaction.payer)
    }

    // MARK: - Validation

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amountDouble: Double {
        Double(amount) ?? 0.0
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty && amountDouble > 0.001
    }

    private var validationMessage: String? {
        if trimmedTitle.isEmpty {
            return "Please enter a title"
        }
        if amountDouble <= 0 {
            return "Amount must be greater than zero"
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Transaction Info Section
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Title")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Transaction title", text: $title)
                            .font(AppTypography.body())
                            .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $title)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Amount")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Text(CurrencyFormatter.currencySymbol)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textSecondary)
                            TextField("0.00", text: $amount)
                                .font(AppTypography.body())
                                .keyboardType(.decimalPad)
                                .limitTextLength(to: 12, text: $amount)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .font(AppTypography.body())
                } header: {
                    Text("Transaction Info")
                        .font(AppTypography.subheadlineMedium())
                }

                // Payer Section
                Section {
                    Picker("Who Paid?", selection: $selectedPayer) {
                        Text("Me").tag(nil as Person?)
                        ForEach(otherPeople) { person in
                            Text(person.displayName).tag(person as Person?)
                        }
                    }
                } header: {
                    Text("Payer")
                        .font(AppTypography.subheadlineMedium())
                }

                // Split Method (read-only display)
                Section {
                    let method = SplitMethod(rawValue: transaction.splitMethod ?? "equal")
                    LabeledContent("Split Method") {
                        Text(method?.displayName ?? "Equal")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Show current splits as read-only info
                    let splits = (transaction.splits as? Set<TransactionSplit> ?? [])
                        .sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }

                    if !splits.isEmpty {
                        ForEach(splits, id: \.objectID) { split in
                            HStack {
                                if let person = split.owedBy {
                                    Text(CurrentUser.isCurrentUser(person.id) ? "You" : person.displayName)
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                } else {
                                    Text("Unknown")
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Text(CurrencyFormatter.format(split.amount))
                                    .font(AppTypography.amountSmall())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Current Splits")
                        .font(AppTypography.subheadlineMedium())
                } footer: {
                    if amountDouble != transaction.amount && amountDouble > 0 {
                        Text("Note: Changing the total amount will proportionally recalculate all splits.")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.warning)
                    }
                }

                // Validation Message
                if let message = validationMessage {
                    Section {
                        Text(message)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.negative)
                    }
                }

                // Save Button
                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSaving)
                    .buttonStyle(PrimaryButtonStyle(isEnabled: isValid && !isSaving))
                    .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.sm, trailing: Spacing.lg))
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .secondarySystemBackground))
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Save Logic

    private func saveChanges() {
        guard isValid else {
            HapticManager.error()
            return
        }

        isSaving = true
        let newAmount = amountDouble
        let oldAmount = transaction.amount

        do {
            // Update basic fields
            transaction.title = trimmedTitle
            transaction.amount = newAmount
            transaction.date = date

            // Update payer
            if let payer = selectedPayer {
                transaction.payer = payer
            } else {
                transaction.payer = CurrentUser.getOrCreate(in: viewContext)
            }

            // Proportionally recalculate splits if amount changed
            if abs(newAmount - oldAmount) > 0.001 && oldAmount > 0.001 {
                let ratio = newAmount / oldAmount
                if let splits = transaction.splits as? Set<TransactionSplit> {
                    for split in splits {
                        split.amount = (split.amount * ratio * 100).rounded() / 100.0
                    }
                }
            }

            try viewContext.save()
            HapticManager.success()
            isSaving = false
            dismiss()
        } catch {
            viewContext.rollback()
            isSaving = false
            HapticManager.error()
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
}
