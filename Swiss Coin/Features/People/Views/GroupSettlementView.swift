//
//  GroupSettlementView.swift
//  Swiss Coin
//
//  Settlement view for settling up with group members.
//

import CoreData
import SwiftUI

struct GroupSettlementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let group: UserGroup

    @State private var selectedMember: Person?
    @State private var selectedCurrency: String?
    @State private var customAmount: String = ""
    @State private var note: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var memberBalances: [(member: Person, balance: CurrencyBalance)] {
        group.getMemberBalances().filter { !$0.balance.isSettled }
    }

    private var selectedMemberBalance: CurrencyBalance {
        guard let member = selectedMember else { return CurrencyBalance() }
        return group.calculateBalanceWith(member: member)
    }

    private var selectedCurrencyAmount: Double {
        guard let code = selectedCurrency else { return selectedMemberBalance.primaryAmount }
        return selectedMemberBalance.nonZero[code] ?? 0
    }

    private var sortedMemberCurrencies: [(code: String, amount: Double)] {
        selectedMemberBalance.sortedCurrencies
    }

    private var isMultiCurrency: Bool {
        sortedMemberCurrencies.count > 1
    }

    private var parsedAmount: Double? {
        CurrencyFormatter.parse(customAmount)
    }

    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0.001 && amount <= abs(selectedCurrencyAmount) + 0.001
    }

    private var directionText: String {
        guard let member = selectedMember else { return "Select a member to settle" }

        let memberName = member.name?.components(separatedBy: " ").first ?? "them"
        if selectedCurrencyAmount > 0 {
            return "Record payment from \(memberName)"
        } else {
            return "Record payment to \(memberName)"
        }
    }

    private var formattedBalance: String {
        if let code = selectedCurrency {
            return CurrencyFormatter.formatAbsolute(selectedCurrencyAmount, currencyCode: code)
        }
        return CurrencyFormatter.formatAbsolute(selectedMemberBalance.primaryAmount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text("Settle Up in \(group.name ?? "Group")")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.top, Spacing.xl)

                    // Member Selection
                    if memberBalances.isEmpty {
                        // No outstanding balances
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: IconSize.xxl))
                                .foregroundColor(AppColors.positive)

                            Text("All settled up!")
                                .font(AppTypography.displayMedium())
                                .foregroundColor(AppColors.textPrimary)

                            Text("There are no outstanding balances in this group.")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.xxl)
                        }
                        .padding(.vertical, Spacing.section)
                    } else {
                        // Member Picker
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Select Member")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, Spacing.xxl)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.md) {
                                    ForEach(memberBalances, id: \.member.id) { item in
                                        MemberBalanceChip(
                                            member: item.member,
                                            balance: item.balance,
                                            isSelected: selectedMember?.id == item.member.id,
                                            onTap: {
                                                HapticManager.selectionChanged()
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedMember = item.member
                                                    selectedCurrency = nil
                                                    customAmount = ""
                                                    // Auto-select currency for this member
                                                    let memberCurrencies = item.balance.sortedCurrencies
                                                    if let single = item.balance.singleCurrency {
                                                        selectedCurrency = single
                                                    } else if let first = memberCurrencies.first {
                                                        selectedCurrency = first.code
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, Spacing.xxl)
                            }
                        }

                        if selectedMember != nil {
                            // Currency selector (if multi-currency for this member)
                            if isMultiCurrency {
                                currencySelector
                            }

                            // Settlement Options
                            VStack(spacing: Spacing.xl) {
                                // Direction and Balance Info
                                VStack(spacing: Spacing.sm) {
                                    Text(directionText)
                                        .font(AppTypography.headingMedium())
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("Current balance: \(formattedBalance)")
                                        .font(AppTypography.bodyDefault())
                                        .foregroundColor(AppColors.textSecondary)
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
                                        if amount > abs(selectedCurrencyAmount) + 0.001 {
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
                            }
                        }
                    }

                    Spacer(minLength: Spacing.section)
                }
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
                // Auto-select first member if available
                if let first = memberBalances.first {
                    selectedMember = first.member
                    if let single = first.balance.singleCurrency {
                        selectedCurrency = single
                    } else if let firstCurrency = first.balance.sortedCurrencies.first {
                        selectedCurrency = firstCurrency.code
                    }
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
                    ForEach(sortedMemberCurrencies, id: \.code) { entry in
                        CurrencyChip(
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
        guard selectedMember != nil else { return }
        createSettlement(amount: abs(selectedCurrencyAmount), isFullSettlement: true)
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
        guard let member = selectedMember else {
            HapticManager.error()
            errorMessage = "Please select a member"
            showingError = true
            return
        }

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

        if selectedCurrencyAmount > 0 {
            // They owe you - they're paying you
            settlement.fromPerson = member
            settlement.toPerson = currentUser
        } else {
            // You owe them - you're paying them
            settlement.fromPerson = currentUser
            settlement.toPerson = member
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

// MARK: - Member Balance Chip

private struct MemberBalanceChip: View {
    let member: Person
    let balance: CurrencyBalance
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color(hex: member.colorHex ?? CurrentUser.defaultColorHex).opacity(0.3))
                    .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                    .overlay(
                        Text(member.initials)
                            .font(AppTypography.headingMedium())
                            .foregroundColor(Color(hex: member.colorHex ?? CurrentUser.defaultColorHex))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 3)
                    )

                Text(member.name?.components(separatedBy: " ").first ?? "User")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                // Show compact multi-currency info
                MultiCurrencyBalanceView(balance: balance, style: .compact)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Currency Chip

private struct CurrencyChip: View {
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
