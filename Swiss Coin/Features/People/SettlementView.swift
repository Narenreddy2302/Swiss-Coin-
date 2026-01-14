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

    private var parsedAmount: Double? {
        Double(customAmount.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }

    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0 && amount <= abs(currentBalance) + 0.01
    }

    private var directionText: String {
        if currentBalance > 0 {
            return "Record payment from \(person.firstName)"
        } else {
            return "Record payment to \(person.firstName)"
        }
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: abs(currentBalance))) ?? "$0.00"
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
        // Fetch the current user Person entity
        let currentUser = fetchCurrentUser()

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
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            dismiss()
        } catch {
            errorMessage = "Failed to save settlement: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func fetchCurrentUser() -> Person? {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", Person.currentUserUUID as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            return nil
        }
    }
}
