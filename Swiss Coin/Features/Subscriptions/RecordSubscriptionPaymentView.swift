//
//  RecordSubscriptionPaymentView.swift
//  Swiss Coin
//
//  View for recording when someone pays for a shared subscription billing cycle.
//

import CoreData
import SwiftUI

struct RecordSubscriptionPaymentView: View {
    @ObservedObject var subscription: Subscription
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var selectedPayer: Person?
    @State private var amount: String
    @State private var date = Date()
    @State private var note = ""
    @State private var showingPayerPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    init(subscription: Subscription) {
        self.subscription = subscription
        _amount = State(initialValue: String(subscription.amount))
    }

    private var canSave: Bool {
        selectedPayer != nil && !amount.isEmpty && (Double(amount) ?? 0) > 0
    }

    private var members: [Person] {
        let subscribersSet = subscription.subscribers as? Set<Person> ?? []
        return Array(subscribersSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Payer Selection
                Section {
                    Button {
                        HapticManager.tap()
                        showingPayerPicker = true
                    } label: {
                        HStack {
                            Text("Who Paid?")
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if let payer = selectedPayer {
                                HStack(spacing: Spacing.sm) {
                                    Circle()
                                        .fill(Color(hex: payer.colorHex ?? "#808080").opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(payer.initials)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(Color(hex: payer.colorHex ?? "#808080"))
                                        )

                                    Text(CurrentUser.isCurrentUser(payer.id) ? "You" : payer.firstName)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            } else {
                                Text("Select")
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                } header: {
                    Text("Payment Details")
                        .font(AppTypography.subheadlineMedium())
                }

                // Amount
                Section {
                    HStack {
                        Text(CurrencyFormatter.currencySymbol)
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Amount")
                        .font(AppTypography.subheadlineMedium())
                }

                // Note
                Section {
                    TextField("Add a note (optional)", text: $note)
                } header: {
                    Text("Note")
                        .font(AppTypography.subheadlineMedium())
                }

                // Split Preview
                Section {
                    let paymentAmount = Double(amount) ?? 0
                    let memberCount = max(1, subscription.subscriberCount)
                    let splitAmount = paymentAmount / Double(memberCount)

                    HStack {
                        Text("Total")
                        Spacer()
                        Text(CurrencyFormatter.format(paymentAmount))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Split \(subscription.subscriberCount) ways")
                        Spacer()
                        Text("\(CurrencyFormatter.format(splitAmount)) each")
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("Split Preview")
                        .font(AppTypography.subheadlineMedium())
                }
            }
            .navigationTitle("Record Payment")
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
                        savePayment()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPayerPicker) {
                PayerPickerView(
                    selectedPayer: $selectedPayer,
                    members: members,
                    viewContext: viewContext
                )
            }
            .onAppear {
                // Default to current user as payer
                selectedPayer = CurrentUser.getOrCreate(in: viewContext)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func savePayment() {
        HapticManager.save()

        // Capture current billing date as the period start before advancing
        let billingPeriodStart = subscription.nextBillingDate ?? date

        // Calculate the new next billing date (period end)
        let newNextBillingDate = subscription.calculateNextBillingDate(from: date)

        let payment = SubscriptionPayment(context: viewContext)
        payment.id = UUID()
        payment.amount = Double(amount) ?? 0
        payment.date = date
        payment.note = note.isEmpty ? nil : note
        payment.payer = selectedPayer
        payment.subscription = subscription
        payment.billingPeriodStart = billingPeriodStart
        payment.billingPeriodEnd = newNextBillingDate

        // Update next billing date
        subscription.nextBillingDate = newNextBillingDate

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save payment: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Payer Picker View

struct PayerPickerView: View {
    @Binding var selectedPayer: Person?
    let members: [Person]
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current User Option
                Section {
                    Button {
                        HapticManager.selectionChanged()
                        selectedPayer = CurrentUser.getOrCreate(in: viewContext)
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: CurrentUser.defaultColorHex).opacity(0.3))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(CurrentUser.initials)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: CurrentUser.defaultColorHex))
                                )

                            Text("You")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if CurrentUser.isCurrentUser(selectedPayer?.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }

                // Members
                Section {
                    ForEach(members) { member in
                        Button {
                            HapticManager.selectionChanged()
                            selectedPayer = member
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: member.colorHex ?? "#808080").opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(member.initials)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: member.colorHex ?? "#808080"))
                                    )

                                Text(member.displayName)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                if selectedPayer?.id == member.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Members")
                        .font(AppTypography.subheadlineMedium())
                }
            }
            .navigationTitle("Who Paid?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
