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

    @State private var customAmount: String = ""
    @State private var note: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var parsedAmount: Double? {
        CurrencyFormatter.parse(customAmount)
    }

    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0.001 && amount <= abs(currentBalance) + 0.001
    }

    private var directionText: String {
        let personName = person.name?.components(separatedBy: " ").first ?? "them"
        if currentBalance > 0 {
            return "Record payment from \(personName)"
        } else {
            return "Record payment to \(personName)"
        }
    }

    private var formattedBalance: String {
        CurrencyFormatter.formatAbsolute(currentBalance)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Text(directionText)
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Current balance: \(formattedBalance)")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, Spacing.xl)

                // Settle Full Amount Button
                Button {
                    HapticManager.tap()
                    settleFullAmount()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.md))
                        Text("Settle Full Amount")
                            .font(AppTypography.bodyBold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.lg)
                    .background(AppColors.positive)
                    .cornerRadius(CornerRadius.md)
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
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
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("$0.00", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .font(AppTypography.title2())
                        .multilineTextAlignment(.center)
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )

                    // Validation hint
                    if let amount = parsedAmount {
                        if amount > abs(currentBalance) + 0.001 {
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
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Add a note...", text: $note)
                        .limitTextLength(to: ValidationLimits.maxNoteLength, text: $note)
                        .font(AppTypography.body())
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
                    HapticManager.tap()
                    settleCustomAmount()
                } label: {
                    Text("Confirm Settlement")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.lg)
                        .background(isValidAmount ? AppColors.accent : AppColors.disabled)
                        .cornerRadius(CornerRadius.md)
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
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
                        HapticManager.tap()
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
            }
        }
    }

    // MARK: - Actions

    private func settleFullAmount() {
        createSettlement(amount: abs(currentBalance), isFullSettlement: true)
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
        settlement.date = Date()
        settlement.note = note.isEmpty ? nil : note
        settlement.isFullSettlement = isFullSettlement

        if currentBalance > 0 {
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
