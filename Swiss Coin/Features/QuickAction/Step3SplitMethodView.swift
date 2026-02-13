//
//  Step3SplitMethodView.swift
//  Swiss Coin
//
//  Step 3: Precise split method configuration and breakdown.
//

import SwiftUI
import UIKit

struct Step3SplitMethodView: View {

    @ObservedObject var viewModel: QuickActionViewModel

    private var sortedParticipantIds: [UUID] {
        Array(viewModel.participantIds).sorted { id1, id2 in
            if id1 == viewModel.currentUserUUID { return true }
            if id2 == viewModel.currentUserUUID { return false }
            return viewModel.getName(for: id1) < viewModel.getName(for: id2)
        }
    }

    private var totalBalance: Double {
        let splits = viewModel.calculateSplits()
        let totalSplit = splits.values.reduce(0.0) { $0 + $1.amount }
        return viewModel.amount - totalSplit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Title
            Text("Split Details")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)

            // MARK: - Split Method
            splitMethodSection
                .padding(.top, Spacing.lg)

            // MARK: - Total Amount Bar
            totalAmountBar
                .padding(.top, Spacing.lg)

            // MARK: - Paid By (only for multi-payer)
            if viewModel.paidByPersons.count > 1 {
                paidByBreakdownSection
                    .padding(.top, Spacing.lg)
            }

            // MARK: - Breakdown
            breakdownSection
                .padding(.top, Spacing.lg)

            Spacer()

            // MARK: - Save Button
            saveButton
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
                .font(AppTypography.bodyBold())
            }
        }
    }

    // MARK: - Split Method Chips

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split Method:")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: Spacing.sm) {
                ForEach(SplitMethod.allCases) { method in
                    methodChip(method: method)
                }
            }
        }
    }

    private func methodChip(method: SplitMethod) -> some View {
        let isSelected = viewModel.splitMethod == method

        return Button {
            HapticManager.selectionChanged()
            dismissKeyboard()
            withAnimation {
                viewModel.splitMethod = method
                viewModel.splitDetails = [:]
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(method.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(
                        isSelected ? AppColors.buttonForeground : AppColors.textPrimary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(isSelected ? AppColors.buttonBackground : Color.clear)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : AppColors.separator,
                                lineWidth: 1
                            )
                    )

                Text(method.displayName)
                    .font(AppTypography.caption2())
                    .foregroundColor(
                        isSelected ? AppColors.textPrimary : AppColors.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Total Amount Bar

    private var totalAmountBar: some View {
        HStack {
            Text("Total Amount")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(viewModel.selectedCurrency.symbol)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)

            Text(String(format: "%.2f", viewModel.amount))
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    // MARK: - Paid By Breakdown

    private var paidByBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            let payers = sortedPayerEntries

            VStack(spacing: 0) {
                ForEach(Array(payers.enumerated()), id: \.element.id) { index, entry in
                    payerAmountRow(
                        name: entry.name,
                        personId: entry.id,
                        isSinglePayer: payers.count == 1
                    )

                    if index < payers.count - 1 {
                        Divider().padding(.horizontal, Spacing.lg)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
        }
    }

    private struct PayerEntry: Identifiable {
        let id: UUID
        let name: String
    }

    private var sortedPayerEntries: [PayerEntry] {
        if viewModel.paidByPersons.isEmpty {
            // Default: "You" pays full amount
            return [PayerEntry(id: viewModel.currentUserUUID, name: "You")]
        }

        var entries: [PayerEntry] = []

        // "You" first if current user is a payer
        if viewModel.paidByPersons.contains(where: { CurrentUser.isCurrentUser($0.id) }) {
            entries.append(PayerEntry(id: viewModel.currentUserUUID, name: "You"))
        }

        // Other payers sorted by name
        let others = viewModel.paidByPersons
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }

        for person in others {
            if let personId = person.id {
                entries.append(PayerEntry(id: personId, name: person.firstName))
            }
        }

        return entries
    }

    private func payerAmountRow(name: String, personId: UUID, isSinglePayer: Bool) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(viewModel.selectedCurrency.symbol)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)

            if isSinglePayer {
                // Single payer: show read-only amount (auto-filled to total)
                Text(String(format: "%.2f", viewModel.amount))
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minWidth: 60, alignment: .trailing)
            } else {
                // Multi-payer: editable amount field
                TextField("0.00", text: payerAmountBinding(for: personId))
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func payerAmountBinding(for personId: UUID) -> Binding<String> {
        Binding<String>(
            get: { viewModel.payerAmountInputs[personId] ?? "" },
            set: { viewModel.payerAmountInputs[personId] = $0 }
        )
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Breakdown:")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            let splits = viewModel.calculateSplits()

            VStack(spacing: Spacing.md) {
                ForEach(sortedParticipantIds, id: \.self) { userId in
                    BreakdownPersonRow(
                        userId: userId,
                        name: viewModel.getName(for: userId),
                        calculatedSplit: splits[userId] ?? SplitDetail(),
                        splitMethod: viewModel.splitMethod,
                        currencySymbol: viewModel.selectedCurrency.symbol,
                        currentDetail: viewModel.splitDetails[userId] ?? SplitDetail(),
                        onUpdate: { viewModel.splitDetails[userId] = $0 }
                    )
                    .id("\(userId)-\(viewModel.splitMethod.rawValue)")
                }
            }

            // Top divider
            balanceDivider

            // Total Balance
            HStack {
                Text("Total Balance")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(viewModel.selectedCurrency.symbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)

                Text(String(format: "%.2f", abs(totalBalance)))
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(
                        abs(totalBalance) < 0.01
                            ? AppColors.textPrimary : AppColors.negative
                    )
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.sm)

            // Bottom divider
            balanceDivider
        }
    }

    private var balanceDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.separator)
                .frame(width: 200, height: 1)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            HapticManager.tap()
            dismissKeyboard()
            if viewModel.canSubmit {
                viewModel.saveTransaction()
            }
        } label: {
            Text("Save Transaction")
                .font(AppTypography.bodyBold())
                .foregroundColor(
                    viewModel.canSubmit
                        ? AppColors.textPrimary : AppColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.xl)
                .background(AppColors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        viewModel.canSubmit
                            ? AppColors.separator : AppColors.disabled,
                        lineWidth: 1
                    )
                )
        }
        .disabled(!viewModel.canSubmit)
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - Breakdown Person Row

/// Displays a single participant's split information with method-specific input.
/// Uses `.id()` on the parent to force re-creation when split method changes,
/// ensuring @State resets properly.
struct BreakdownPersonRow: View {
    let userId: UUID
    let name: String
    let calculatedSplit: SplitDetail
    let splitMethod: SplitMethod
    let currencySymbol: String
    let currentDetail: SplitDetail
    let onUpdate: (SplitDetail) -> Void

    @State private var inputText: String = ""
    @State private var shares: Int = 1

    var body: some View {
        HStack {
            Text(name)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer()

            splitInput
        }
        .padding(.horizontal, Spacing.sm)
        .onAppear { initializeInput() }
    }

    private func initializeInput() {
        switch splitMethod {
        case .amount:
            inputText = currentDetail.amount > 0
                ? String(format: "%.2f", currentDetail.amount) : ""
        case .percentage:
            inputText = currentDetail.percentage > 0
                ? String(format: "%.0f", currentDetail.percentage) : ""
        case .shares:
            shares = max(currentDetail.shares, 1)
        case .adjustment:
            inputText = currentDetail.adjustment != 0
                ? String(format: "%.2f", currentDetail.adjustment) : ""
        default:
            break
        }
    }

    @ViewBuilder
    private var splitInput: some View {
        switch splitMethod {
        case .equal:
            currencyAmountDisplay(calculatedSplit.amount)

        case .amount:
            HStack(spacing: Spacing.sm) {
                Text(currencySymbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                TextField("0.00", text: $inputText)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 80)
                    .onChange(of: inputText) {
                        var detail = currentDetail
                        detail.amount = Double(inputText) ?? 0
                        onUpdate(detail)
                    }
            }

        case .percentage:
            HStack(spacing: Spacing.sm) {
                TextField("0", text: $inputText)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 50)
                    .onChange(of: inputText) {
                        var detail = currentDetail
                        detail.percentage = Double(inputText) ?? 0
                        onUpdate(detail)
                    }
                Text("%")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
            }

        case .shares:
            HStack(spacing: Spacing.sm) {
                Button {
                    guard shares > 1 else { return }
                    shares -= 1
                    var detail = currentDetail
                    detail.shares = shares
                    onUpdate(detail)
                    HapticManager.selectionChanged()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.backgroundTertiary)
                        .clipShape(Circle())
                }

                Text("\(shares)")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 30)
                    .multilineTextAlignment(.center)

                Button {
                    shares += 1
                    var detail = currentDetail
                    detail.shares = shares
                    onUpdate(detail)
                    HapticManager.selectionChanged()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.backgroundTertiary)
                        .clipShape(Circle())
                }
            }

        case .adjustment:
            HStack(spacing: Spacing.sm) {
                Text("±\(currencySymbol)")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                TextField("0", text: $inputText)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 60)
                    .onChange(of: inputText) {
                        var detail = currentDetail
                        detail.adjustment = Double(inputText) ?? 0
                        onUpdate(detail)
                    }
            }
        }
    }

    private func currencyAmountDisplay(_ amount: Double) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(currencySymbol)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
            Text(String(format: "%.2f", amount))
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 60, alignment: .trailing)
        }
    }
}
