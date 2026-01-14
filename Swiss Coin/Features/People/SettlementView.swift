//
//  SettlementView.swift
//  Swiss Coin
//

import CoreData
import SwiftUI

struct SettlementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let person: Person
    let currentBalance: Double

    @State private var customAmount: String = ""
    @State private var note: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // Retained haptic generator for reliable feedback
    private let hapticGenerator = UINotificationFeedbackGenerator()

    private var parsedAmount: Double? {
        CurrencyFormatter.parse(customAmount)
    }

    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        // Amount must be positive and not exceed the absolute balance
        // Using small epsilon for floating point comparison
        return amount > 0.001 && amount <= abs(currentBalance) + 0.001
    }

    private var directionText: String {
        if currentBalance > 0 {
            return "Record payment from \(person.firstName)"
        } else {
            return "Record payment to \(person.firstName)"
        }
    }

    private var formattedBalance: String {
        CurrencyFormatter.formatAbsolute(currentBalance)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(directionText)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Current balance: \(formattedBalance)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Settle Full Amount Button
                Button {
                    settleFullAmount()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Settle Full Amount")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 24)

                // Custom Amount Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Amount")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("$0.00", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )

                    // Validation hint
                    if let amount = parsedAmount {
                        if amount > abs(currentBalance) + 0.001 {
                            Text("Amount cannot exceed \(formattedBalance)")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if amount <= 0.001 {
                            Text("Amount must be greater than $0.00")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Note Field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Add a note...", text: $note)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Confirm Custom Amount Button
                Button {
                    settleCustomAmount()
                } label: {
                    Text("Confirm Settlement")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValidAmount ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isValidAmount)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                hapticGenerator.prepare()
            }
        }
    }

    // MARK: - Actions

    private func settleFullAmount() {
        createSettlement(amount: abs(currentBalance), isFullSettlement: true)
    }

    private func settleCustomAmount() {
        guard let amount = parsedAmount, isValidAmount else {
            errorMessage = "Please enter a valid amount"
            showingError = true
            return
        }
        createSettlement(amount: amount, isFullSettlement: false)
    }

    private func createSettlement(amount: Double, isFullSettlement: Bool) {
        // Validate amount
        guard amount > 0 else {
            errorMessage = "Settlement amount must be greater than zero"
            showingError = true
            return
        }

        // Get or create the current user (ensures it exists)
        let currentUser = CurrentUser.getOrCreate(in: viewContext)

        let settlement = Settlement(context: viewContext)
        settlement.id = UUID()
        settlement.amount = amount
        settlement.date = Date()
        settlement.note = note.isEmpty ? nil : note
        settlement.isFullSettlement = isFullSettlement

        // Determine direction based on balance
        if currentBalance > 0 {
            // They owe you - they're paying you
            settlement.fromPerson = person
            settlement.toPerson = currentUser
        } else {
            // You owe them - you're paying them
            settlement.fromPerson = currentUser
            settlement.toPerson = person
        }

        do {
            try viewContext.save()

            // Haptic feedback
            hapticGenerator.notificationOccurred(.success)

            dismiss()
        } catch {
            // Rollback on failure
            viewContext.rollback()

            errorMessage = "Failed to save settlement: \(error.localizedDescription)"
            showingError = true
        }
    }
}
