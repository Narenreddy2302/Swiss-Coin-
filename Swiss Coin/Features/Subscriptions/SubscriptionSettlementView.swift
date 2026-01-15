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

    var body: some View {
        NavigationStack {
            Form {
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
                                        .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(item.member.initials)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hex: item.member.colorHex ?? "#808080"))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.member.firstName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)

                                        Text("owes you \(CurrencyFormatter.format(item.amount))")
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
                            .font(AppTypography.subheadlineMedium())
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
                                        .fill(Color(hex: item.member.colorHex ?? "#808080").opacity(0.3))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(item.member.initials)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color(hex: item.member.colorHex ?? "#808080"))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.member.firstName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)

                                        Text("you owe \(CurrencyFormatter.format(item.amount))")
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
                            .font(AppTypography.subheadlineMedium())
                    } footer: {
                        Text("Select a member you have paid back")
                            .font(AppTypography.caption())
                    }
                }

                // Amount
                if selectedMember != nil {
                    Section {
                        HStack {
                            Text("$")
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                        }

                        TextField("Add a note (optional)", text: $note)
                    } header: {
                        Text("Settlement Amount")
                            .font(AppTypography.subheadlineMedium())
                    }
                }

                // Empty state
                if membersWhoOweYou.isEmpty && membersYouOwe.isEmpty {
                    Section {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.positive)

                            Text("All Settled Up!")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Everyone's subscription share is paid.")
                                .font(AppTypography.subheadline())
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
        }
    }

    private func saveSettlement() {
        guard let member = selectedMember else { return }

        HapticManager.save()

        let settlement = SubscriptionSettlement(context: viewContext)
        settlement.id = UUID()
        settlement.amount = Double(amount) ?? 0
        settlement.date = Date()
        settlement.note = note.isEmpty ? nil : note
        settlement.subscription = subscription

        // Determine direction based on who owes who
        let balance = subscription.calculateBalanceWith(member: member)
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
            dismiss()
        } catch {
            print("Error saving settlement: \(error)")
        }
    }
}
