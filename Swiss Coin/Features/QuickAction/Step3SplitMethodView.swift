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
        VStack(spacing: 20) {

            // MARK: Split Method Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(QuickActionSplitMethod.allCases) { method in
                        SplitMethodChip(
                            method: method,
                            isSelected: viewModel.splitMethod == method
                        ) {
                            withAnimation {
                                viewModel.splitMethod = method
                                viewModel.splitDetails = [:]  // Reset details when method changes
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, -20)  // Bleed out? or just standard.
            // Actually ScrollView fits parent width usually.

            // MARK: Total Summary Bar
            SplitSummaryBar(viewModel: viewModel)

            // MARK: Per-Person Split Details
            VStack(spacing: 0) {
                let splits = viewModel.calculateSplits()
                // Sort participants for stable order (Me first, then alphabetical)
                let participantIds = Array(viewModel.participantIds).sorted { id1, id2 in
                    if id1 == viewModel.currentUserUUID { return true }
                    if id2 == viewModel.currentUserUUID { return false }
                    return viewModel.getName(for: id1) < viewModel.getName(for: id2)
                }

                ForEach(Array(participantIds.enumerated()), id: \.element) { index, userId in
                    let split = splits[userId] ?? SplitDetail()
                    let isLast = index == participantIds.count - 1
                    // Payer check:
                    // viewModel.paidByPerson is Person? (nil=Me).
                    // userId is UUID. (currentUserUUID=Me).
                    let payerId = viewModel.paidByPerson?.id ?? viewModel.currentUserUUID
                    let isPayer = payerId == userId

                    let name = viewModel.getName(for: userId)
                    let initials = viewModel.getInitials(for: userId)
                    let isMe = userId == viewModel.currentUserUUID

                    SplitPersonRow(
                        name: name,
                        initials: initials,
                        isCurrentUser: isMe,
                        split: split,
                        isPayer: isPayer,
                        currency: viewModel.selectedCurrency,
                        splitMethod: viewModel.splitMethod,
                        currentDetail: viewModel.splitDetails[userId] ?? SplitDetail(),
                        onUpdate: { detail in
                            viewModel.splitDetails[userId] = detail
                        }
                    )

                    if !isLast {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)

            // MARK: Who Owes Whom Summary
            OwesSummaryView(viewModel: viewModel)

            // MARK: Navigation Buttons
            HStack(spacing: 12) {
                // Back button
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                }

                // Save button
                Button {
                    if viewModel.canSubmit {
                        viewModel.saveTransaction()
                    }
                } label: {
                    Text("Save Transaction")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                                .opacity(viewModel.canSubmit ? 1 : 0.5)
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
                .font(.system(size: 17))
                .foregroundColor(.secondary)

            Text("\(viewModel.selectedCurrency.symbol)\(viewModel.amount, specifier: "%.2f")")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            // Validation indicator
            if viewModel.splitMethod == .percentages {
                let isValid = abs(viewModel.totalPercentage - 100) < 0.1
                Text("\(viewModel.totalPercentage, specifier: "%.0f")%")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isValid ? .green : .red)
            } else if viewModel.splitMethod == .amounts {
                let isValid = abs(viewModel.totalSplitAmount - viewModel.amount) < 0.01
                Text(
                    "\(viewModel.selectedCurrency.symbol)\(viewModel.totalSplitAmount, specifier: "%.2f")"
                )
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(isValid ? .green : .red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SplitPersonRow: View {
    let name: String
    let initials: String
    let isCurrentUser: Bool
    let split: SplitDetail
    let isPayer: Bool
    let currency: Currency
    let splitMethod: QuickActionSplitMethod
    let currentDetail: SplitDetail
    let onUpdate: (SplitDetail) -> Void

    @State private var amountText: String = ""
    @State private var percentageText: String = ""
    @State private var shares: Int = 1
    @State private var adjustmentText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            PersonAvatar(
                initials: initials,
                isCurrentUser: isCurrentUser,
                isSelected: false,
                size: 40
            )

            // Name and amount
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 17, weight: .medium))

                    // Payer badge
                    if isPayer {
                        Text("Paid")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }

                Text("\(currency.symbol)\(split.amount, specifier: "%.2f")")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Input control based on split method
            splitInputView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
            // Just show the percentage share
            // We can calculate rough percentage: 100 / count (but count isn't here)
            // Or just split.percentage
            Text("\(split.percentage, specifier: "%.0f")%")
                .font(.system(size: 17))
                .foregroundColor(.secondary)

        case .amounts:
            HStack(spacing: 4) {
                Text(currency.symbol)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                TextField(
                    "0", text: $amountText,
                    onEditingChanged: { _ in
                        // commit on finish?
                    },
                    onCommit: {
                        var detail = currentDetail
                        detail.amount = Double(amountText) ?? 0
                        onUpdate(detail)
                    }
                )
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                // Also update on change for smoother UI or wait for commit?
                // Reference used onChange.
                .onChange(of: amountText) {
                    var detail = currentDetail
                    detail.amount = Double(amountText) ?? 0
                    onUpdate(detail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)

        case .percentages:
            HStack(spacing: 4) {
                TextField("0", text: $percentageText)
                    .font(.system(size: 17))
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: percentageText) {
                        var detail = currentDetail
                        detail.percentage = Double(percentageText) ?? 0
                        onUpdate(detail)
                    }
                Text("%")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)

        case .shares:
            HStack(spacing: 4) {
                Button {
                    if shares > 1 {
                        shares -= 1
                        var detail = currentDetail
                        detail.shares = shares
                        onUpdate(detail)
                    }
                } label: {
                    Text("−")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                }

                Text("\(shares)")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 40)
                    .multilineTextAlignment(.center)

                Button {
                    shares += 1
                    var detail = currentDetail
                    detail.shares = shares
                    onUpdate(detail)
                } label: {
                    Text("+")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                }
            }
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)

        case .adjustment:
            HStack(spacing: 4) {
                Text("±\(currency.symbol)")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                TextField("0", text: $adjustmentText)
                    .font(.system(size: 17))
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .onChange(of: adjustmentText) {
                        var detail = currentDetail
                        detail.adjustment = Double(adjustmentText) ?? 0
                        onUpdate(detail)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
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
            VStack(spacing: 0) {
                ForEach(Array(nonPayerParticipants), id: \.self) { userId in
                    let name = viewModel.getName(for: userId)
                    let split = splits[userId] ?? SplitDetail()

                    HStack {
                        Text("\(name) owes \(payerName)")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(
                            "\(viewModel.selectedCurrency.symbol)\(split.amount, specifier: "%.2f")"
                        )
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
        }
    }
}
