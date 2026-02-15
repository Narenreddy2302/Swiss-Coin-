//
//  SubscriptionSettlementView.swift
//  Swiss Coin
//
//  View for settling balances between subscription members.
//

import CoreData
import SwiftUI

struct SubscriptionSettlementView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var selectedMember: Person?
    @State private var amount: String = ""
    @State private var note = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSettleAllConfirmation = false
    @State private var isSettlingAll = false

    private var memberBalances: [(member: Person, balance: Double, paid: Double)] {
        subscription.getMemberBalances()
    }

    private var membersWhoOweYou: [(member: Person, amount: Double)] {
        subscription.getMembersWhoOweYou()
    }

    private var membersYouOwe: [(member: Person, amount: Double)] {
        subscription.getMembersYouOwe()
    }

    private var canSave: Bool {
        selectedMember != nil && !amount.isEmpty && (Double(amount) ?? 0) > 0
    }

    /// The outstanding balance for the currently selected member
    private var outstandingBalance: Double {
        guard let member = selectedMember else { return 0 }
        return abs(subscription.calculateBalanceWith(member: member))
    }

    /// Whether the entered amount exceeds the outstanding balance
    private var isOverSettlement: Bool {
        guard selectedMember != nil else { return false }
        let enteredAmount = Double(amount) ?? 0
        return enteredAmount > outstandingBalance + 0.01
    }

    // MARK: - Settle All Computed Properties

    /// Total amount others owe you
    private var totalOwedToYou: Double {
        membersWhoOweYou.reduce(0) { $0 + $1.amount }
    }

    /// Total amount you owe others
    private var totalYouOwe: Double {
        membersYouOwe.reduce(0) { $0 + $1.amount }
    }

    /// Count of members who owe you
    private var countOwedToYou: Int {
        membersWhoOweYou.count
    }

    /// Count of members you owe
    private var countYouOwe: Int {
        membersYouOwe.count
    }

    /// Whether settle all should be shown (multiple pending settlements)
    private var showSettleAllSection: Bool {
        let totalMembers = countOwedToYou + countYouOwe
        return totalMembers >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Settle All Section
                if showSettleAllSection {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            // Summary text
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                if countOwedToYou > 0 {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(AppColors.positive)
                                            .font(.system(size: IconSize.sm))
                                        Text("\(countOwedToYou) \(countOwedToYou == 1 ? "person owes" : "people owe") you \(CurrencyFormatter.format(totalOwedToYou))")
                                            .font(AppTypography.bodyDefault())
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }

                                if countYouOwe > 0 {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(AppColors.negative)
                                            .font(.system(size: IconSize.sm))
                                        Text("You owe \(countYouOwe) \(countYouOwe == 1 ? "person" : "people") \(CurrencyFormatter.format(totalYouOwe))")
                                            .font(AppTypography.bodyDefault())
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                            }

                            // Settle All button
                            Button {
                                HapticManager.tap()
                                showingSettleAllConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: IconSize.md))
                                    Text("Settle All Balances")
                                        .font(AppTypography.buttonDefault())
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isSettlingAll)
                        }
                        .padding(.vertical, Spacing.xs)
                    } header: {
                        Text("Quick Settlement")
                            .font(AppTypography.labelLarge())
                    } footer: {
                        Text("Record all outstanding balances as settled in one action")
                            .font(AppTypography.caption())
                    }
                }

                // Members who owe you
                if !membersWhoOweYou.isEmpty {
                    Section {
                        ForEach(membersWhoOweYou, id: \.member.id) { item in
                            Button {
                                HapticManager.selectionChanged()
                                selectedMember = item.member
                                amount = String(format: "%.2f", item.amount)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.3))
                                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                        .overlay(
                                            Text(item.member.initials)
                                                .font(AppTypography.labelDefault())
                                                .foregroundColor(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex))
                                        )

                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(item.member.firstName)
                                            .font(AppTypography.bodyLarge())
                                            .foregroundColor(AppColors.textPrimary)

                                        (Text("owes you ") + Text(CurrencyFormatter.format(item.amount)).fontWeight(.bold))
                                            .font(AppTypography.caption())
                                            .foregroundColor(AppColors.positive)
                                    }

                                    Spacer()

                                    if selectedMember?.id == item.member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Collect from")
                            .font(AppTypography.labelLarge())
                    } footer: {
                        Text("Select a member who has paid you back")
                            .font(AppTypography.caption())
                    }
                }

                // Members you owe
                if !membersYouOwe.isEmpty {
                    Section {
                        ForEach(membersYouOwe, id: \.member.id) { item in
                            Button {
                                HapticManager.selectionChanged()
                                selectedMember = item.member
                                amount = String(format: "%.2f", item.amount)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.3))
                                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                        .overlay(
                                            Text(item.member.initials)
                                                .font(AppTypography.labelDefault())
                                                .foregroundColor(Color(hex: item.member.colorHex ?? AppColors.defaultAvatarColorHex))
                                        )

                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(item.member.firstName)
                                            .font(AppTypography.bodyLarge())
                                            .foregroundColor(AppColors.textPrimary)

                                        (Text("you owe ") + Text(CurrencyFormatter.format(item.amount)).fontWeight(.bold))
                                            .font(AppTypography.caption())
                                            .foregroundColor(AppColors.negative)
                                    }

                                    Spacer()

                                    if selectedMember?.id == item.member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Pay to")
                            .font(AppTypography.labelLarge())
                    } footer: {
                        Text("Select a member you have paid back")
                            .font(AppTypography.caption())
                    }
                }

                // Amount
                if selectedMember != nil {
                    Section {
                        HStack {
                            Text(CurrencyFormatter.currencySymbol)
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                        }

                        if isOverSettlement {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.warning)
                                    .font(.system(size: IconSize.sm))

                                (Text("Amount exceeds outstanding balance of ") + Text(CurrencyFormatter.format(outstandingBalance)).fontWeight(.bold) + Text(". It will be capped."))
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.warning)
                            }
                        }

                        TextField("Add a note (optional)", text: $note)
                            .limitTextLength(to: ValidationLimits.maxNoteLength, text: $note)
                    } header: {
                        Text("Settlement Amount")
                            .font(AppTypography.labelLarge())
                    }
                }

                // Empty state
                if membersWhoOweYou.isEmpty && membersYouOwe.isEmpty {
                    Section {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: IconSize.xxl))
                                .foregroundColor(AppColors.positive)

                            Text("All Settled Up!")
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Everyone's subscription share is paid.")
                                .font(AppTypography.bodyDefault())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    }
                }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettlement()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Settle All Balances", isPresented: $showingSettleAllConfirmation) {
                Button("Cancel", role: .cancel) {
                    HapticManager.cancel()
                }
                Button("Settle All", role: .none) {
                    settleAllBalances()
                }
            } message: {
                Text(settleAllSummaryMessage)
            }
        }
    }

    // MARK: - Settle All Summary Message

    private var settleAllSummaryMessage: String {
        var parts: [String] = []

        if countOwedToYou > 0 {
            parts.append("\(countOwedToYou) \(countOwedToYou == 1 ? "person" : "people") will be marked as paid (\(CurrencyFormatter.format(totalOwedToYou)) collected)")
        }

        if countYouOwe > 0 {
            parts.append("You will be marked as having paid \(countYouOwe) \(countYouOwe == 1 ? "person" : "people") (\(CurrencyFormatter.format(totalYouOwe)) paid)")
        }

        let totalSettlements = countOwedToYou + countYouOwe
        parts.append("\nThis will create \(totalSettlements) settlement \(totalSettlements == 1 ? "record" : "records").")

        return parts.joined(separator: "\n")
    }

    private func saveSettlement() {
        guard let member = selectedMember else { return }

        HapticManager.save()

        // Recalculate current balance right before creating settlement to prevent over-settlement
        // This guards against race conditions where balance changed after user entered amount
        let currentBalance = subscription.calculateBalanceWith(member: member)
        let currentMaxAmount = abs(currentBalance)

        // If there's no outstanding balance, don't create a settlement
        guard currentMaxAmount > 0.01 else {
            errorMessage = "This balance has already been settled."
            showingError = true
            return
        }

        // Cap settlement amount at the current outstanding balance
        let enteredAmount = Double(amount) ?? 0
        let settlementAmount = min(enteredAmount, currentMaxAmount)

        // Validate that we have a positive settlement amount
        guard settlementAmount > 0 else {
            errorMessage = "Please enter a valid amount."
            showingError = true
            return
        }

        let settlement = SubscriptionSettlement(context: viewContext)
        settlement.id = UUID()
        settlement.amount = settlementAmount
        settlement.date = Date()
        settlement.note = note.isEmpty ? nil : note
        settlement.subscription = subscription

        // Determine direction based on current balance (recalculated above)
        let balance = currentBalance
        if balance > 0 {
            // They owe you, so they paid you
            settlement.fromPerson = member
            settlement.toPerson = CurrentUser.getOrCreate(in: viewContext)
        } else {
            // You owe them, so you paid them
            settlement.fromPerson = CurrentUser.getOrCreate(in: viewContext)
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

    // MARK: - Settle All Balances

    private func settleAllBalances() {
        isSettlingAll = true
        HapticManager.save()

        let currentUser = CurrentUser.getOrCreate(in: viewContext)
        let settlementDate = Date()
        var settlementsCreated = 0

        // Create settlements for members who owe the current user
        for item in membersWhoOweYou {
            // Recalculate balance to prevent over-settlement
            let currentBalance = subscription.calculateBalanceWith(member: item.member)
            let settlementAmount = max(0, currentBalance) // They owe if positive

            guard settlementAmount > 0.01 else { continue }

            let settlement = SubscriptionSettlement(context: viewContext)
            settlement.id = UUID()
            settlement.amount = settlementAmount
            settlement.date = settlementDate
            settlement.note = "Bulk settlement"
            settlement.subscription = subscription
            settlement.fromPerson = item.member  // They paid you
            settlement.toPerson = currentUser

            settlementsCreated += 1
        }

        // Create settlements for members the current user owes
        for item in membersYouOwe {
            // Recalculate balance to prevent over-settlement
            let currentBalance = subscription.calculateBalanceWith(member: item.member)
            let settlementAmount = abs(min(0, currentBalance)) // You owe if negative

            guard settlementAmount > 0.01 else { continue }

            let settlement = SubscriptionSettlement(context: viewContext)
            settlement.id = UUID()
            settlement.amount = settlementAmount
            settlement.date = settlementDate
            settlement.note = "Bulk settlement"
            settlement.subscription = subscription
            settlement.fromPerson = currentUser  // You paid them
            settlement.toPerson = item.member

            settlementsCreated += 1
        }

        // Save all settlements in a single transaction
        do {
            if settlementsCreated > 0 {
                try viewContext.save()
                HapticManager.success()
                dismiss()
            } else {
                isSettlingAll = false
                errorMessage = "No outstanding balances to settle."
                showingError = true
            }
        } catch {
            viewContext.rollback()
            isSettlingAll = false
            HapticManager.error()
            errorMessage = "Failed to save settlements: \(error.localizedDescription)"
            showingError = true
        }
    }
}
