//
//  Step1BasicDetailsView.swift
//  Swiss Coin
//
//  Step 1: Basic transaction details.
//

import SwiftUI
import UIKit

struct Step1BasicDetailsView: View {

    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: 20) {

            // MARK: Transaction Type Segmented Control
            Picker("Transaction Type", selection: $viewModel.transactionType) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            // MARK: Amount Input Section
            HStack(spacing: 12) {
                // Currency selector button
                Button {
                    withAnimation {
                        viewModel.showCurrencyPicker.toggle()
                        viewModel.showCategoryPicker = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.selectedCurrency.flag)
                            .font(.system(size: 20))
                        Text(viewModel.selectedCurrency.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(8)
                }

                // Amount text field
                TextField("0.00", text: $viewModel.amountString)
                    .font(.system(size: 48, weight: .regular))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)

            // MARK: Currency Picker
            if viewModel.showCurrencyPicker {
                CurrencyPickerView(
                    currencies: Currency.all,
                    selectedCurrency: $viewModel.selectedCurrency,
                    isPresented: $viewModel.showCurrencyPicker
                )
            }

            // MARK: Description & Category Fields
            VStack(spacing: 0) {
                // Description input row
                HStack {
                    Text("Description")
                        .font(.system(size: 17))
                    Spacer()
                    TextField("What's this for?", text: $viewModel.transactionName)
                        .font(.system(size: 17))
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 16)

                // Category selector row
                Button {
                    withAnimation {
                        viewModel.showCategoryPicker.toggle()
                        viewModel.showCurrencyPicker = false
                    }
                } label: {
                    HStack {
                        Text("Category")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        Spacer()
                        if let category = viewModel.selectedCategory {
                            HStack(spacing: 6) {
                                Text(category.icon)
                                Text(category.name)
                                    .foregroundColor(category.color)
                            }
                            .font(.system(size: 17))
                        } else {
                            Text("Select")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)

            // MARK: Category Picker
            if viewModel.showCategoryPicker {
                CategoryPickerView(
                    categories: Category.all,
                    selectedCategory: $viewModel.selectedCategory,
                    isPresented: $viewModel.showCategoryPicker
                )
            }

            // MARK: Continue Button
            Button {
                if viewModel.canProceedStep1 {
                    viewModel.nextStep()
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                            .opacity(viewModel.canProceedStep1 ? 1 : 0.5)
                    )
            }
            .disabled(!viewModel.canProceedStep1)
        }
    }
}
