//
//  Step3SplitMethodView.swift
//  Swiss Coin
//
//  Step 3: Precise split method configuration.
//

import SwiftUI
import UIKit

struct Step3SplitMethodView: View {

    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {

            // MARK: Split Method Picker
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Split method")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(SplitMethod.allCases) { method in
                            SplitMethodChip(
                                method: method,
                                isSelected: viewModel.splitMethod == method
                            ) {
                                withAnimation {
                                    viewModel.splitMethod = method
                                    viewModel.splitDetails = [:]
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Total Summary Bar
            SplitSummaryBar(viewModel: viewModel)

            // MARK: Per-Person Split Details
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Breakdown")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 0) {
                    let splits = viewModel.calculateSplits()
                    let participantIds = Array(viewModel.participantIds).sorted { id1, id2 in
                        if id1 == viewModel.currentUserUUID { return true }
                        if id2 == viewModel.currentUserUUID { return false }
                        return viewModel.getName(for: id1) < viewModel.getName(for: id2)
                    }

                    ForEach(Array(participantIds.enumerated()), id: \.element) { index, userId in
                        let split = splits[userId] ?? SplitDetail()
                        let payerId = viewModel.paidByPerson?.id ?? viewModel.currentUserUUID
                        let isPayer = payerId == userId
                        let name = viewModel.getName(for: userId)
                        let initials = viewModel.getInitials(for: userId)
                        let isMe = userId == viewModel.currentUserUUID

                        if index > 0 {
                            Divider()
                                .padding(.leading, Spacing.xxl + Spacing.xl)
                        }

                        SplitPersonRow(
                            name: name,
                            initials: initials,
                            isCurrentUser: isMe,
                            split: split,
                            isPayer: isPayer,
                            splitMethod: viewModel.splitMethod,
                            currentDetail: viewModel.splitDetails[userId] ?? SplitDetail(),
                            onUpdate: { detail in
                                viewModel.splitDetails[userId] = detail
                            }
                        )
                    }
                }
            }

            // MARK: Who Owes Whom Summary
            OwesSummaryView(viewModel: viewModel)

            // MARK: Navigation Buttons
            HStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, Spacing.xl)
                        .frame(height: ButtonHeight.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )
                }

                Button {
                    HapticManager.tap()
                    if viewModel.canSubmit {
                        viewModel.saveTransaction()
                    }
                } label: {
                    Text("Save Transaction")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.buttonForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(viewModel.canSubmit ? AppColors.buttonBackground : AppColors.disabled)
                        )
                }
                .disabled(!viewModel.canSubmit)
            }
        }
    }
}

// MARK: - Subviews

struct SplitSummaryBar: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        HStack {
            Text("Total")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)

            Text("\(CurrencyFormatter.currencySymbol)\(viewModel.amount, specifier: "%.2f")")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if viewModel.splitMethod == .percentage {
                let isValid = abs(viewModel.totalPercentage - 100) < 0.1
                Text("\(viewModel.totalPercentage, specifier: "%.0f")%")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(isValid ? AppColors.positive : AppColors.negative)
            } else if viewModel.splitMethod == .amount {
                let isValid = abs(viewModel.totalSplitAmount - viewModel.amount) < 0.01
                Text(
                    "\(CurrencyFormatter.currencySymbol)\(viewModel.totalSplitAmount, specifier: "%.2f")"
                )
                .font(AppTypography.bodyBold())
                .foregroundColor(isValid ? AppColors.positive : AppColors.negative)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.sm)
    }
}

struct SplitPersonRow: View {
    let name: String
    let initials: String
    let isCurrentUser: Bool
    let split: SplitDetail
    let isPayer: Bool
    let splitMethod: SplitMethod
    let currentDetail: SplitDetail
    let onUpdate: (SplitDetail) -> Void

    @State private var amountText: String = ""
    @State private var percentageText: String = ""
    @State private var shares: Int = 1
    @State private var adjustmentText: String = ""

    var body: some View {
        HStack(spacing: Spacing.md) {
            PersonAvatar(
                initials: initials,
                isCurrentUser: isCurrentUser,
                isSelected: false,
                size: 44
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(name)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    if isPayer {
                        Text("Paid")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.buttonForeground)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(AppColors.accent)
                            .cornerRadius(10)
                    }
                }

                Text("\(CurrencyFormatter.currencySymbol)\(split.amount, specifier: "%.2f")")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            splitInputView
        }
        .padding(.vertical, Spacing.sm)
        .onAppear {
            updateDerivedState()
        }
        .onChange(of: currentDetail.amount) { updateDerivedState() }
        .onChange(of: currentDetail.percentage) { updateDerivedState() }
        .onChange(of: currentDetail.shares) { updateDerivedState() }
        .onChange(of: currentDetail.adjustment) { updateDerivedState() }
    }

    private func updateDerivedState() {
        amountText = currentDetail.amount > 0 ? String(format: "%.2f", currentDetail.amount) : ""
        percentageText =
            currentDetail.percentage > 0 ? String(format: "%.0f", currentDetail.percentage) : ""
        shares = currentDetail.shares > 0 ? currentDetail.shares : 1
        adjustmentText =
            currentDetail.adjustment != 0 ? String(format: "%.2f", currentDetail.adjustment) : ""
    }

    @ViewBuilder
    private var splitInputView: some View {
        switch splitMethod {
        case .equal:
            Text("\(split.percentage, specifier: "%.0f")%")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)

        case .amount:
            HStack(spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                TextField(
                    "0", text: $amountText,
                    onEditingChanged: { _ in },
                    onCommit: {
                        var detail = currentDetail
                        detail.amount = Double(amountText) ?? 0
                        onUpdate(detail)
                    }
                )
                .font(AppTypography.body())
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .onChange(of: amountText) {
                    var detail = currentDetail
                    detail.amount = Double(amountText) ?? 0
                    onUpdate(detail)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.sm)

        case .percentage:
            HStack(spacing: Spacing.xxs) {
                TextField("0", text: $percentageText)
                    .font(AppTypography.body())
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: percentageText) {
                        var detail = currentDetail
                        detail.percentage = Double(percentageText) ?? 0
                        onUpdate(detail)
                    }
                Text("%")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.sm)

        case .shares:
            HStack(spacing: Spacing.xxs) {
                Button {
                    if shares > 1 {
                        shares -= 1
                        var detail = currentDetail
                        detail.shares = shares
                        onUpdate(detail)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 32, height: 32)
                }

                Text("\(shares)")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 32)
                    .multilineTextAlignment(.center)

                Button {
                    shares += 1
                    var detail = currentDetail
                    detail.shares = shares
                    onUpdate(detail)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 32, height: 32)
                }
            }
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.sm)

        case .adjustment:
            HStack(spacing: Spacing.xxs) {
                Text("±\(CurrencyFormatter.currencySymbol)")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                TextField("0", text: $adjustmentText)
                    .font(AppTypography.body())
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: adjustmentText) {
                        var detail = currentDetail
                        detail.adjustment = Double(adjustmentText) ?? 0
                        onUpdate(detail)
                    }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.sm)
        }
    }
}

struct OwesSummaryView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        let splits = viewModel.calculateSplits()
        let payerId = viewModel.paidByPerson?.id ?? viewModel.currentUserUUID
        let payerName = viewModel.getName(for: payerId)
        let nonPayerParticipants = viewModel.participantIds.filter { $0 != payerId }

        if !nonPayerParticipants.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Settlement")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(nonPayerParticipants.enumerated()), id: \.element) { index, userId in
                        let name = viewModel.getName(for: userId)
                        let split = splits[userId] ?? SplitDetail()

                        if index > 0 {
                            Divider()
                        }

                        HStack {
                            Text("\(name) owes \(payerName)")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text(
                                "\(CurrencyFormatter.currencySymbol)\(split.amount, specifier: "%.2f")"
                            )
                            .font(AppTypography.bodyBold())
                            .foregroundColor(AppColors.accent)
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }
            }
        }
    }
}
