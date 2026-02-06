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
        VStack(alignment: .leading, spacing: Spacing.xxl) {

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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Amount")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: Spacing.md) {
                    Button {
                        HapticManager.tap()
                        viewModel.showCurrencyPicker = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(viewModel.selectedCurrency.flag)
                                .font(.system(size: 20))
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

                    TextField("0.00", text: $viewModel.amountString)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            // MARK: Description Field
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Description")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                TextField("What's this for?", text: $viewModel.transactionName)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)
            }

            // MARK: Category Field
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Category")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                Button {
                    HapticManager.tap()
                    viewModel.showCategoryPicker = true
                } label: {
                    HStack {
                        if let category = viewModel.selectedCategory {
                            HStack(spacing: Spacing.sm) {
                                Text(category.icon)
                                    .font(.system(size: 20))
                                Text(category.name)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        } else {
                            Text("Select a category")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: Spacing.sm)

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
