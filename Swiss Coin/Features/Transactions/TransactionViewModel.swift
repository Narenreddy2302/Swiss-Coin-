import Combine
import CoreData
import SwiftUI

enum SplitMethod: String, CaseIterable, Identifiable {
    case equal = "Equal"
    case percentage = "Percentage"
    case exact = "Exact Amount"
    case adjustment = "Adjustment"
    case shares = "Shares"

    var id: String { self.rawValue }

    var systemImage: String {
        switch self {
        case .equal: return "equal"
        case .percentage: return "percent"
        case .exact: return "dollarsign.circle"
        case .adjustment: return "plus.forwardslash.minus"
        case .shares: return "chart.pie.fill"
        }
    }
}

final class TransactionViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var totalAmount: String = ""
    @Published var date: Date = Date()
    @Published var selectedPayer: Person?

    @Published var selectedParticipants: Set<Person> = []
    @Published var splitMethod: SplitMethod = .equal

    // Store raw input for each person (e.g. 50% or +10 adjustment or 2 shares)
    // Map PersonID -> Double
    @Published var rawInputs: [UUID: String] = [:]

    // Optional group for group transactions
    var selectedGroup: UserGroup?

    private var viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    var totalAmountDouble: Double {
        return Double(totalAmount) ?? 0.0
    }

    // Current total calculated based on inputs (for validation)
    var currentCalculatedTotal: Double {
        switch splitMethod {
        case .equal:
            return totalAmountDouble
        case .percentage:
            let totalPercent = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return totalPercent  // Should be 100
        case .exact:
            let totalExact = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return totalExact  // Should match totalAmountDouble
        case .adjustment:
            // Adjustment logic: (Total - Sum(Adjustments)) / N + Adjustment
            // The math is internal, validation checks if inputs are valid numbers
            return totalAmountDouble
        case .shares:
            // Just shares count
            return totalAmountDouble
        }
    }

    var isValid: Bool {
        guard !title.isEmpty, totalAmountDouble > 0, !selectedParticipants.isEmpty else {
            return false
        }

        switch splitMethod {
        case .equal:
            return true
        case .percentage:
            return abs(currentCalculatedTotal - 100.0) < 0.1
        case .exact:
            return abs(currentCalculatedTotal - totalAmountDouble) < 0.01
        case .adjustment:
            return true  // Typically always valid unless adjustments exceed total
        case .shares:
            let totalShares = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return totalShares > 0
        }
    }

    func calculateSplit(for person: Person) -> Double {
        guard let targetId = person.id else { return 0 }
        let count = selectedParticipants.count
        if count == 0 { return 0 }

        // Consistent sorting to ensure deterministic penny distribution
        let sortedPeople = selectedParticipants.sorted { ($0.name ?? "") < ($1.name ?? "") }
        guard let index = sortedPeople.firstIndex(of: person) else { return 0 }

        let totalCents = Int(totalAmountDouble * 100)

        switch splitMethod {
        case .equal:
            let baseCents = totalCents / count
            let remainder = totalCents % count
            // Distribute remainder to first 'remainder' people
            let myCents = baseCents + (index < remainder ? 1 : 0)
            return Double(myCents) / 100.0

        case .percentage:
            let raw = Double(rawInputs[targetId] ?? "0") ?? 0
            return totalAmountDouble * (raw / 100.0)

        case .exact:
            return Double(rawInputs[targetId] ?? "0") ?? 0

        case .adjustment:
            // Calculate total adjustments (in cents to be safe)
            let totalAdjustmentCents = selectedParticipants.reduce(0) { sum, p in
                let adj = Double(rawInputs[p.id ?? UUID()] ?? "0") ?? 0
                return sum + Int(adj * 100)
            }

            // Remaining total ensures Base Split logic
            let remainingTotalCents = totalCents - totalAdjustmentCents
            let baseCents = remainingTotalCents / count
            let remainder = remainingTotalCents % count

            // Base share + My specific adjustment
            let myBaseCents = baseCents + (index < remainder ? 1 : 0)
            let myAdjCents = Int((Double(rawInputs[targetId] ?? "0") ?? 0) * 100)

            return Double(myBaseCents + myAdjCents) / 100.0

        case .shares:
            let totalShares = selectedParticipants.reduce(0.0) { sum, p in
                sum + (Double(rawInputs[p.id ?? UUID()] ?? "0") ?? 0)
            }
            if totalShares == 0 { return 0 }

            let myShares = Double(rawInputs[targetId] ?? "0") ?? 0
            // Simple share calculation for now, but could use penny logic if strict requirement
            // Using standard double math for shares as "parts" usually implies non-currency units but let's stick to standard behavior unless specified
            return (myShares / totalShares) * totalAmountDouble
        }
    }

    func saveTransaction(presentationMode: Binding<PresentationMode>) {
        let transaction = FinancialTransaction(context: viewContext)
        transaction.id = UUID()
        transaction.title = title
        transaction.amount = totalAmountDouble
        transaction.date = date

        // If no payer selected ("Me"), use current user; otherwise use selected person
        if let payer = selectedPayer {
            transaction.payer = payer
        } else {
            // "Me" was selected - use current user
            transaction.payer = CurrentUser.getOrCreate(in: viewContext)
        }

        transaction.splitMethod = splitMethod.rawValue

        // Assign group if this is a group transaction
        if let group = selectedGroup {
            transaction.group = group
        }

        // Save Splits
        for person in selectedParticipants {
            let splitData = TransactionSplit(context: viewContext)
            splitData.owedBy = person
            splitData.transaction = transaction
            splitData.amount = calculateSplit(for: person)
            // Save raw input for future editing capability
            if let rawString = rawInputs[person.id ?? UUID()], let rawVal = Double(rawString) {
                splitData.rawAmount = rawVal
            }
        }

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving: \(error)")
        }
    }
}
