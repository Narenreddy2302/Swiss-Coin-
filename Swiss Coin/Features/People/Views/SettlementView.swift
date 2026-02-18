//
//  SettlementView.swift
//  Swiss Coin
//

import CoreData
import SwiftUI

struct SettlementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let person: Person
    let currentBalance: Double
    let currentCurrencyBalance: CurrencyBalance

    @State private var selectedCurrency: String?
    @State private var customAmount: String = ""
    @State private var note: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var sortedCurrencies: [(code: String, amount: Double)] {
        currentCurrencyBalance.sortedCurrencies
    }

    private var isMultiCurrency: Bool {
        sortedCurrencies.count > 1
    }

    private var selectedBalanceAmount: Double {
        guard let code = selectedCurrency else { return currentBalance }
        return currentCurrencyBalance.nonZero[code] ?? 0
    }

    private var parsedAmount: Double? {
        CurrencyFormatter.parse(customAmount)
    }

    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0.001 && amount <= abs(selectedBalanceAmount) + 0.001
    }

    private var directionText: String {
        let personName = person.name?.components(separatedBy: " ").first ?? "them"
        if selectedBalanceAmount > 0 {
            return "Record payment from \(personName)"
        } else {
            return "Record payment to \(personName)"
        }
    }

    private var formattedBalance: String {
        if let code = selectedCurrency {
            return CurrencyFormatter.formatAbsolute(selectedBalanceAmount, currencyCode: code)
        }
        return CurrencyFormatter.formatAbsolute(currentBalance)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Text(directionText)
                        .font(AppTypography.headingMedium())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Current balance: \(formattedBalance)")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, Spacing.xl)

                // Currency selector (multi-currency only)
                if isMultiCurrency {
                    currencySelector
                }

                // Settle Full Amount Button
                Button {
                    HapticManager.primaryAction()
                    settleFullAmount()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.md))
                        Text("Settle Full Amount")
                            .font(AppTypography.buttonDefault())
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)

                // Divider
                HStack {
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    Rectangle()
                        .fill(AppColors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, Spacing.xxl)

                // Custom Amount Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Custom Amount")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("$0.00", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .font(AppTypography.displayMedium())
                        .multilineTextAlignment(.center)
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )

                    // Validation hint
                    if let amount = parsedAmount {
                        if amount > abs(selectedBalanceAmount) + 0.001 {
                            Text("Amount cannot exceed \(formattedBalance)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.negative)
                        } else if amount <= 0.001 {
                            Text("Amount must be greater than $0.00")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.negative)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xxl)

                // Note Field
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Note (optional)")
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Add a note...", text: $note)
                        .limitTextLength(to: ValidationLimits.maxNoteLength, text: $note)
                        .font(AppTypography.bodyLarge())
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Confirm Custom Amount Button
                Button {
                    HapticManager.primaryAction()
                    settleCustomAmount()
                } label: {
                    Text("Confirm Settlement")
                        .font(AppTypography.buttonDefault())
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isValidAmount))
                .disabled(!isValidAmount)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xl)
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
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
            .onAppear {
                HapticManager.prepare()
                // Auto-select: single currency or largest balance
                if let single = currentCurrencyBalance.singleCurrency {
                    selectedCurrency = single
                } else if let first = sortedCurrencies.first {
                    selectedCurrency = first.code
                }
            }
        }
    }

    // MARK: - Currency Selector

    @ViewBuilder
    private var currencySelector: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Currency")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.xxl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(sortedCurrencies, id: \.code) { entry in
                        CurrencyBalanceChip(
                            currencyCode: entry.code,
                            amount: entry.amount,
                            isSelected: selectedCurrency == entry.code,
                            onTap: {
                                HapticManager.selectionChanged()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCurrency = entry.code
                                    customAmount = ""
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.xxl)
            }
        }
    }

    // MARK: - Actions

    private func settleFullAmount() {
        createSettlement(amount: abs(selectedBalanceAmount), isFullSettlement: true)
    }

    private func settleCustomAmount() {
        guard let amount = parsedAmount, isValidAmount else {
            HapticManager.error()
            errorMessage = "Please enter a valid amount"
            showingError = true
            return
        }
        createSettlement(amount: amount, isFullSettlement: false)
    }

    private func createSettlement(amount: Double, isFullSettlement: Bool) {
        guard amount > 0 else {
            HapticManager.error()
            errorMessage = "Settlement amount must be greater than zero"
            showingError = true
            return
        }

        let currentUser = CurrentUser.getOrCreate(in: viewContext)

        let settlement = Settlement(context: viewContext)
        settlement.id = UUID()
        settlement.amount = amount
        settlement.currency = selectedCurrency
        settlement.date = Date()
        settlement.note = note.isEmpty ? nil : note
        settlement.isFullSettlement = isFullSettlement

        if selectedBalanceAmount > 0 {
            settlement.fromPerson = person
            settlement.toPerson = currentUser
        } else {
            settlement.fromPerson = currentUser
            settlement.toPerson = person
        }

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save settlement: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Currency Balance Chip

private struct CurrencyBalanceChip: View {
    let currencyCode: String
    let amount: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var balanceColor: Color {
        if amount > 0.01 { return AppColors.positive }
        else if amount < -0.01 { return AppColors.negative }
        else { return AppColors.neutral }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                Text(CurrencyFormatter.flag(for: currencyCode))
                    .font(.system(size: 28))

                Text(currencyCode)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textPrimary)

                Text(CurrencyFormatter.formatAbsolute(amount, currencyCode: currencyCode))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(balanceColor)
            }
            .frame(width: 80)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(isSelected ? AppColors.accentMuted : AppColors.backgroundTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
