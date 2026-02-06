//
//  Step1BasicDetailsView.swift
//  Swiss Coin
//
//  Step 1: Basic transaction details.
//

import SwiftUI

struct Step1BasicDetailsView: View {

    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {

            // MARK: Transaction Type Segmented Control
            Picker("Transaction Type", selection: $viewModel.transactionType) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.transactionType) { _, _ in
                HapticManager.selectionChanged()
            }

            // MARK: Amount Input Section
            HStack(spacing: Spacing.md) {
                // Currency selector button
                Button {
                    HapticManager.tap()
                    viewModel.showCurrencyPicker = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(viewModel.selectedCurrency.flag)
                            .font(.system(size: IconSize.md))
                        Text(viewModel.selectedCurrency.symbol)
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)
                }
                .buttonStyle(.plain)

                // Amount text field
                TextField("0.00", text: $viewModel.amountString)
                    .font(.system(size: 48, weight: .regular, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(Spacing.lg)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)

            // MARK: Description & Category Fields
            VStack(spacing: 0) {
                // Description input row
                HStack {
                    Text("Description")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    TextField("What's this for?", text: $viewModel.transactionName)
                        .font(AppTypography.body())
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

                Divider()
                    .padding(.leading, Spacing.lg)

                // Category selector row
                Button {
                    HapticManager.tap()
                    viewModel.showCategoryPicker = true
                } label: {
                    HStack {
                        Text("Category")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if let category = viewModel.selectedCategory {
                            HStack(spacing: Spacing.xs) {
                                Text(category.icon)
                                Text(category.name)
                                    .foregroundColor(category.color)
                            }
                            .font(AppTypography.body())
                        } else {
                            Text("Select")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: IconSize.sm, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)

            // MARK: Continue Button
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
                            .fill(viewModel.canProceedStep1 ? AppColors.buttonBackground : AppColors.disabled)
                    )
            }
            .disabled(!viewModel.canProceedStep1)
        }
        .sheet(isPresented: $viewModel.showCurrencyPicker) {
            CurrencyPickerSheet(
                selectedCurrency: $viewModel.selectedCurrency,
                isPresented: $viewModel.showCurrencyPicker
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showCategoryPicker) {
            CategoryPickerSheet(
                selectedCategory: $viewModel.selectedCategory,
                isPresented: $viewModel.showCategoryPicker
            )
            .presentationDetents([.medium, .large])
        }
    }
}
