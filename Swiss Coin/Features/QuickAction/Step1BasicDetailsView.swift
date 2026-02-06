//
//  Step1BasicDetailsView.swift
//  Swiss Coin
//
//  Step 1: Basic transaction details — name, date, currency, and amount.
//

import SwiftUI

struct Step1BasicDetailsView: View {

    @ObservedObject var viewModel: QuickActionViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case amount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Title
            Text("New Transaction")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            // MARK: - Transaction Name
            TextField("Transaction Name", text: $viewModel.transactionName)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }
                .limitTextLength(
                    to: ValidationLimits.maxTransactionTitleLength,
                    text: $viewModel.transactionName
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
                .padding(.top, Spacing.md)

            // MARK: - Date / Currency / Amount Row
            HStack(spacing: Spacing.sm) {

                // Date picker (compact inline)
                DatePicker(
                    "",
                    selection: $viewModel.transactionDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.textPrimary)
                .fixedSize()

                Spacer()

                // Currency selector
                Button {
                    HapticManager.tap()
                    focusedField = nil
                    viewModel.showCurrencyPicker = true
                } label: {
                    Text(viewModel.selectedCurrency.symbol)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(AppColors.backgroundTertiary)
                        .cornerRadius(CornerRadius.xs)
                }
                .buttonStyle(.plain)

                // Amount input
                TextField("0.00", text: $viewModel.amountString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .amount)
                    .limitTextLength(to: 12, text: $viewModel.amountString)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            .padding(.top, Spacing.xxs)

            Spacer()

            // MARK: - Continue Button
            Button {
                HapticManager.tap()
                if viewModel.canProceedStep1 {
                    viewModel.nextStep()
                }
            } label: {
                Text("Continue")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.buttonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(
                                viewModel.canProceedStep1
                                    ? AppColors.buttonBackground : AppColors.disabled
                            )
                    )
            }
            .disabled(!viewModel.canProceedStep1)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(AppTypography.bodyBold())
            }
        }
        .sheet(isPresented: $viewModel.showCurrencyPicker) {
            CurrencyPickerSheet(
                selectedCurrency: $viewModel.selectedCurrency,
                isPresented: $viewModel.showCurrencyPicker
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
    }
}
