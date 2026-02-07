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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // MARK: - Hero Amount Section
                        amountSection

                        // MARK: - Transaction Info Card
                        transactionInfoCard

                        // MARK: - Payer Card
                        payerCard

                        // MARK: - Current Splits Card (read-only)
                        currentSplitsCard

                        // MARK: - Validation
                        validationSection

                        // Bottom padding for save button
                        Spacer()
                            .frame(height: ButtonHeight.xl + Spacing.section)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)

                // MARK: - Floating Save Button
                saveButton
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.cancel()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
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

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: Spacing.md) {
            Text("Total Amount")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(amount.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)

                TextField("0.00", text: $amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .limitTextLength(to: 12, text: $amount)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackground)
            )
        }
    }

    // MARK: - Transaction Info Card

    private var transactionInfoCard: some View {
        VStack(spacing: 0) {
            // Title Field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Title")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("Transaction title", text: $title)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $title)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()
                .padding(.leading, Spacing.lg)

            // Date Picker
            HStack {
                Text("Date")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Payer Card

    private var payerCard: some View {
        VStack(spacing: 0) {
            Picker("Who Paid?", selection: $selectedPayer) {
                Text("Me").tag(nil as Person?)
                ForEach(otherPeople) { person in
                    Text(person.displayName).tag(person as Person?)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Current Splits Card

    private var currentSplitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Current Splits")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                let method = SplitMethod(rawValue: transaction.splitMethod ?? "equal")
                if let method = method {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: method.systemImage)
                            .font(.system(size: IconSize.sm))
                        Text(method.displayName)
                            .font(AppTypography.caption())
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)

            Divider()
                .padding(.leading, Spacing.lg)

            // Splits
            let splits = (transaction.splits as? Set<TransactionSplit> ?? [])
                .sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }

            if !splits.isEmpty {
                ForEach(splits, id: \.objectID) { split in
                    HStack(spacing: Spacing.md) {
                        // Avatar
                        if let person = split.owedBy {
                            Circle()
                                .fill(person.avatarBackgroundColor)
                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                .overlay(
                                    Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(person.avatarTextColor)
                                )
                        } else {
                            Circle()
                                .fill(AppColors.backgroundTertiary)
                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                .overlay(
                                    Text("?")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                )
                        }

                        // Name
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

                        // Amount
                        Text(CurrencyFormatter.format(split.amount))
                            .font(AppTypography.amountSmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)

                    if split != splits.last {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.sm + Spacing.md)
                    }
                }
            } else {
                Text("No splits configured")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
            }

            // Recalculation notice
            if amountDouble != transaction.amount && amountDouble > 0 {
                Divider()

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.warning)

                    Text("Changing the total will proportionally recalculate all splits.")
                        .font(AppTypography.footnote())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Validation Section

    @ViewBuilder
    private var validationSection: some View {
        if let message = validationMessage {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.warning)

                Text(message)
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(AppColors.warning.opacity(0.08))
            )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Spacing.xxl)

            Button {
                saveChanges()
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(AppColors.buttonForeground)
                } else {
                    Text("Save Changes")
                }
            }
            .disabled(!isValid || isSaving)
            .buttonStyle(PrimaryButtonStyle(isEnabled: isValid && !isSaving))
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .background(AppColors.backgroundSecondary)
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
