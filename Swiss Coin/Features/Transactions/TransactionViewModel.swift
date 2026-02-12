import Combine
import CoreData
import Foundation
import os
import SwiftUI

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var totalAmount: String = ""
    @Published var date: Date = Date()
    @Published var note: String = ""

    // MARK: - Multi-Payer Support
    /// Selected payers (empty means "You" pays the full amount)
    @Published var selectedPayerPersons: Set<Person> = []
    /// Amount each payer contributed, keyed by Person UUID
    @Published var payerAmounts: [UUID: String] = [:]

    /// Backward-compatible single payer alias (used by TwoPartySplitView)
    var selectedPayer: Person? {
        if selectedPayerPersons.count == 1 {
            return selectedPayerPersons.first
        }
        return nil // nil = "You" or multi-payer
    }

    @Published var selectedParticipants: Set<Person> = []
    @Published var splitMethod: SplitMethod = .equal

    // Store raw input for each person (e.g. 50% or +10 adjustment or 2 shares)
    // Map PersonID -> Double
    @Published var rawInputs: [UUID: String] = [:]

    // Optional group for group transactions
    var selectedGroup: UserGroup?

    // MARK: - Search Fields (for redesigned UI)
    @Published var paidBySearchText: String = ""
    @Published var splitWithSearchText: String = ""

    // Cached contact/group lists to avoid fetching on every property access
    @Published private(set) var cachedPaidByContacts: [Person] = []
    @Published private(set) var cachedSplitWithContacts: [Person] = []
    @Published private(set) var cachedSplitWithGroups: [UserGroup] = []

    private var viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.viewContext = context

        // Default payer ("You") should be in the split by default
        let currentUser = CurrentUser.getOrCreate(in: context)
        selectedParticipants.insert(currentUser)

        // Initial fetch
        refreshAllContacts()
        refreshAllGroups()

        setupSearchListeners()
    }

    // MARK: - Search Functionality

    private func setupSearchListeners() {
        $paidBySearchText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.refreshPaidByContacts(query: text)
            }
            .store(in: &cancellables)

        $splitWithSearchText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.refreshSplitWithContacts(query: text)
                self?.refreshSplitWithGroups(query: text)
            }
            .store(in: &cancellables)
    }

    private func refreshAllContacts() {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        let all = (try? viewContext.fetch(fetchRequest)) ?? []
        cachedPaidByContacts = all
        cachedSplitWithContacts = all
    }

    private func refreshAllGroups() {
        let fetchRequest: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]
        cachedSplitWithGroups = (try? viewContext.fetch(fetchRequest)) ?? []
    }

    private func refreshPaidByContacts(query: String) {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        if !query.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        }
        cachedPaidByContacts = (try? viewContext.fetch(fetchRequest)) ?? []
    }

    private func refreshSplitWithContacts(query: String) {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        if !query.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        }
        cachedSplitWithContacts = (try? viewContext.fetch(fetchRequest)) ?? []
    }

    private func refreshSplitWithGroups(query: String) {
        let fetchRequest: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]
        if !query.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        }
        cachedSplitWithGroups = (try? viewContext.fetch(fetchRequest)) ?? []
    }

    /// Filtered contacts for "Paid By" search
    var filteredPaidByContacts: [Person] {
        cachedPaidByContacts
    }

    /// Filtered contacts for "Split With" search
    var filteredSplitWithContacts: [Person] {
        cachedSplitWithContacts
    }

    /// Filtered groups for "Split With" search
    var filteredSplitWithGroups: [UserGroup] {
        cachedSplitWithGroups
    }

    // MARK: - Computed Properties

    /// Step 1 validation: title non-empty AND amount > 0.001
    var isStep1Valid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && totalAmountDouble > 0.001
    }

    /// Step 2 validation: at least one participant selected
    var isStep2Valid: Bool {
        !selectedParticipants.isEmpty
    }

    // MARK: - Multi-Payer Computed Properties

    /// Total amount paid by all selected payers
    var totalPaidByPayers: Double {
        selectedPayerPersons.reduce(0.0) { sum, person in
            sum + (Double(payerAmounts[person.id ?? UUID()] ?? "0") ?? 0)
        }
    }

    /// Whether paid-by amounts balance with the total transaction amount
    var isPaidByBalanced: Bool {
        if selectedPayerPersons.count <= 1 {
            return true // Single payer auto-fills to total
        }
        return abs(totalPaidByPayers - totalAmountDouble) < 0.01
    }

    /// Toggle a payer's selection. Auto-adds them to participants.
    func togglePayer(_ person: Person) {
        if selectedPayerPersons.contains(person) {
            selectedPayerPersons.remove(person)
            payerAmounts.removeValue(forKey: person.id ?? UUID())
        } else {
            selectedPayerPersons.insert(person)
            // Also add them as a participant if not already
            if !selectedParticipants.contains(person) {
                selectedParticipants.insert(person)
            }
        }
    }

    /// Toggle "You" as a payer
    func toggleCurrentUserAsPayer(in context: NSManagedObjectContext) {
        let currentUser = CurrentUser.getOrCreate(in: context)
        togglePayer(currentUser)
    }

    /// Whether the current user is among the selected payers
    var isCurrentUserPayer: Bool {
        if selectedPayerPersons.isEmpty { return true } // Default: "You" pays
        return selectedPayerPersons.contains { CurrentUser.isCurrentUser($0.id) }
    }

    // MARK: - Two-Party Split Detection

    /// Whether this is a 2-party split (current user + exactly 1 other person) with single payer
    var isTwoPartySplit: Bool {
        let otherParticipants = selectedParticipants.filter { !CurrentUser.isCurrentUser($0.id) }
        return otherParticipants.count == 1 && selectedParticipants.count == 2
            && selectedPayerPersons.count <= 1
    }

    /// The other person in a 2-party split
    var twoPartyOtherPerson: Person? {
        guard isTwoPartySplit else { return nil }
        return selectedParticipants.first { !CurrentUser.isCurrentUser($0.id) }
    }

    /// Amount the other person owes You (when You paid)
    var twoPartyTheyOweYou: Double {
        guard isTwoPartySplit, let other = twoPartyOtherPerson else { return 0 }
        guard selectedPayer == nil else { return 0 }
        return calculateSplit(for: other)
    }

    /// Amount You owe the other person (when they paid)
    var twoPartyYouOweThem: Double {
        guard isTwoPartySplit, let other = twoPartyOtherPerson else { return 0 }
        guard let payer = selectedPayer, payer.id == other.id else { return 0 }
        if let currentUserPerson = selectedParticipants.first(where: { CurrentUser.isCurrentUser($0.id) }) {
            return calculateSplit(for: currentUserPerson)
        }
        return 0
    }

    var totalAmountDouble: Double {
        return Double(totalAmount) ?? 0.0
    }

    /// Total balance calculation for validation display
    var totalBalance: Double {
        let splits = selectedParticipants.map { calculateSplit(for: $0) }
        let totalSplit = splits.reduce(0.0, +)
        return totalAmountDouble - totalSplit
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
        case .amount:
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
        // 1. Title validation - trim whitespace
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        // 2. Amount validation - must be positive (using 0.001 threshold for floating-point safety)
        guard totalAmountDouble > 0.001 else { return false }

        // 3. Participant validation - at least one person
        guard !selectedParticipants.isEmpty else { return false }

        // 4. Multi-payer validation: paid amounts must sum to total
        if selectedPayerPersons.count > 1 {
            guard isPaidByBalanced else { return false }
        }

        // 5. Split method specific validation
        switch splitMethod {
        case .equal:
            return true

        case .percentage:
            let totalPercent = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return abs(totalPercent - 100.0) < 0.1

        case .amount:
            let totalExact = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return abs(totalExact - totalAmountDouble) < 0.01

        case .adjustment:
            // Ensure total adjustments don't exceed total amount
            let totalAdjustments = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return totalAdjustments <= totalAmountDouble

        case .shares:
            let totalShares = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            return totalShares > 0
        }
    }

    /// User-facing validation message for when isValid is false
    var validationMessage: String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            return "Please enter a title"
        }
        if totalAmountDouble <= 0 {
            return "Amount must be greater than zero"
        }
        if selectedParticipants.isEmpty {
            return "Select at least one participant"
        }

        // Multi-payer validation
        if selectedPayerPersons.count > 1 && !isPaidByBalanced {
            return "Paid-by amounts must equal the total"
        }

        switch splitMethod {
        case .percentage:
            let totalPercent = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if abs(totalPercent - 100.0) >= 0.1 {
                return "Percentages must add up to 100%"
            }
        case .amount:
            let totalExact = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if abs(totalExact - totalAmountDouble) >= 0.01 {
                return "Amounts must equal the total"
            }
        case .adjustment:
            let totalAdjustments = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if totalAdjustments > totalAmountDouble {
                return "Adjustments cannot exceed the total amount"
            }
        case .shares:
            let totalShares = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if totalShares <= 0 {
                return "Enter shares for at least one person"
            }
        default:
            break
        }

        return nil
    }

    // MARK: - Actions

    /// Toggle a participant's selection
    func toggleParticipant(_ person: Person) {
        if selectedParticipants.contains(person) {
            selectedParticipants.remove(person)
        } else {
            selectedParticipants.insert(person)
        }
    }

    /// Select all members of a group
    func selectGroup(_ group: UserGroup) {
        guard let members = group.members as? Set<Person> else { return }
        for member in members {
            selectedParticipants.insert(member)
        }
        selectedGroup = group
    }

    // MARK: - Split Calculation

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

        case .amount:
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
            guard totalShares > 0 else { return 0 }

            let myShares = Double(rawInputs[targetId] ?? "0") ?? 0

            // Use penny-perfect calculation for shares too
            let myShareRatio = myShares / totalShares
            let myCents = Int(round(myShareRatio * Double(totalCents)))
            return Double(myCents) / 100.0
        }
    }

    // MARK: - Save Transaction

    func saveTransaction(completion: @escaping (Bool) -> Void = { _ in }) {
        // 1. Pre-flight validation
        guard isValid else {
            HapticManager.error()
            completion(false)
            return
        }

        // 2. Trim title
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // 3. Create transaction entity
            let transaction = FinancialTransaction(context: viewContext)
            transaction.id = UUID()
            transaction.title = cleanTitle
            transaction.amount = totalAmountDouble
            transaction.date = date
            transaction.splitMethod = splitMethod.rawValue

            // Set note (nil if empty)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.note = trimmedNote.isEmpty ? nil : trimmedNote

            // 4. Set legacy payer field for backward compatibility
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            if selectedPayerPersons.isEmpty {
                transaction.payer = currentUser
            } else if selectedPayerPersons.count == 1 {
                transaction.payer = selectedPayerPersons.first
            } else {
                // Multi-payer: set legacy payer to current user if they're a payer, else first payer
                if let currentUserPayer = selectedPayerPersons.first(where: { CurrentUser.isCurrentUser($0.id) }) {
                    transaction.payer = currentUserPayer
                } else {
                    transaction.payer = selectedPayerPersons.sorted { ($0.name ?? "") < ($1.name ?? "") }.first
                }
            }

            // 5. Create TransactionPayer records
            if selectedPayerPersons.isEmpty {
                // Default: "You" pays the full amount
                let payerRecord = TransactionPayer(context: viewContext)
                payerRecord.paidBy = currentUser
                payerRecord.transaction = transaction
                payerRecord.amount = totalAmountDouble
            } else if selectedPayerPersons.count == 1, let singlePayer = selectedPayerPersons.first {
                // Single payer: auto-fill to total
                let payerRecord = TransactionPayer(context: viewContext)
                payerRecord.paidBy = singlePayer
                payerRecord.transaction = transaction
                payerRecord.amount = totalAmountDouble
            } else {
                // Multi-payer: use entered amounts
                for person in selectedPayerPersons {
                    let payerRecord = TransactionPayer(context: viewContext)
                    payerRecord.paidBy = person
                    payerRecord.transaction = transaction
                    let amountStr = payerAmounts[person.id ?? UUID()] ?? "0"
                    payerRecord.amount = Double(amountStr) ?? 0
                }
            }

            // 6. Set creator (always the current user)
            transaction.createdBy = currentUser

            // 7. Assign group if this is a group transaction
            if let group = selectedGroup {
                transaction.group = group
            }

            // 8. Create splits for each participant
            for person in selectedParticipants {
                let splitData = TransactionSplit(context: viewContext)
                splitData.owedBy = person
                splitData.transaction = transaction
                splitData.amount = calculateSplit(for: person)

                // Preserve raw input for editing
                if let personId = person.id,
                   let rawString = rawInputs[personId],
                   let rawVal = Double(rawString) {
                    splitData.rawAmount = rawVal
                }
            }

            // 8. Save to CoreData
            try viewContext.save()

            // 9. Success feedback
            HapticManager.success()

            // 10. Call completion handler
            completion(true)

        } catch {
            // 11. Handle save error
            viewContext.rollback()
            HapticManager.error()
            AppLogger.transactions.error("Failed to save transaction: \(error.localizedDescription)")
            completion(false)
        }
    }

    /// Reset the form to default values
    func resetForm() {
        title = ""
        totalAmount = ""
        date = Date()
        note = ""
        selectedPayerPersons = []
        payerAmounts = [:]
        selectedParticipants = []
        splitMethod = .equal
        rawInputs = [:]
        selectedGroup = nil
        paidBySearchText = ""
        splitWithSearchText = ""

        // Default payer ("You") should be in the split by default
        let currentUser = CurrentUser.getOrCreate(in: viewContext)
        selectedParticipants.insert(currentUser)
    }

    // MARK: - Load Transaction for Editing

    /// Populates the ViewModel form state from an existing transaction.
    func loadTransaction(_ transaction: FinancialTransaction) {
        title = transaction.title ?? ""
        totalAmount = String(format: "%.2f", transaction.amount)
        date = transaction.date ?? Date()
        note = transaction.note ?? ""

        // Split method
        if let methodStr = transaction.splitMethod,
           let method = SplitMethod(rawValue: methodStr) {
            splitMethod = method
        }

        // Group
        selectedGroup = transaction.group

        // Load payers from TransactionPayer records
        selectedPayerPersons = []
        payerAmounts = [:]
        let payerRecords = (transaction.payers as? Set<TransactionPayer>) ?? []

        if payerRecords.isEmpty {
            // Legacy transaction without TransactionPayer records
            if let legacyPayer = transaction.payer, !CurrentUser.isCurrentUser(legacyPayer.id) {
                selectedPayerPersons.insert(legacyPayer)
            }
        } else {
            for tp in payerRecords {
                if let person = tp.paidBy {
                    selectedPayerPersons.insert(person)
                    if let personId = person.id {
                        payerAmounts[personId] = String(format: "%.2f", tp.amount)
                    }
                }
            }
            // If single payer is the current user, keep empty (default "You" behavior)
            if selectedPayerPersons.count == 1,
               let singlePayer = selectedPayerPersons.first,
               CurrentUser.isCurrentUser(singlePayer.id) {
                selectedPayerPersons = []
                payerAmounts = [:]
            }
        }

        // Load participants and raw inputs from splits
        selectedParticipants = []
        rawInputs = [:]
        if let splitSet = transaction.splits as? Set<TransactionSplit> {
            for split in splitSet {
                if let person = split.owedBy {
                    selectedParticipants.insert(person)
                    if let personId = person.id {
                        loadRawInput(from: split, personId: personId, totalAmount: transaction.amount)
                    }
                }
            }
        }
    }

    private func loadRawInput(from split: TransactionSplit, personId: UUID, totalAmount: Double) {
        switch splitMethod {
        case .equal:
            break
        case .percentage:
            if split.rawAmount > 0 {
                rawInputs[personId] = formatRawValue(split.rawAmount, for: .percentage)
            } else if totalAmount > 0 {
                let pct = (split.amount / totalAmount) * 100
                rawInputs[personId] = formatRawValue(pct, for: .percentage)
            }
        case .shares:
            if split.rawAmount > 0 {
                rawInputs[personId] = formatRawValue(split.rawAmount, for: .shares)
            } else {
                rawInputs[personId] = "1"
            }
        case .adjustment:
            rawInputs[personId] = formatRawValue(split.rawAmount, for: .adjustment)
        case .amount:
            rawInputs[personId] = String(format: "%.2f", split.amount)
        }
    }

    private func formatRawValue(_ value: Double, for method: SplitMethod) -> String {
        switch method {
        case .shares:
            return String(Int(value))
        case .percentage:
            if value == value.rounded() {
                return String(format: "%.0f", value)
            }
            return String(format: "%.1f", value)
        default:
            if value == 0 { return "0" }
            return String(format: "%.2f", value)
        }
    }

    // MARK: - Update Existing Transaction

    /// Updates an existing transaction with the current form state.
    func updateTransaction(_ transaction: FinancialTransaction, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isValid else {
            HapticManager.error()
            completion(false)
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Update basic fields
            transaction.title = cleanTitle
            transaction.amount = totalAmountDouble
            transaction.date = date
            transaction.splitMethod = splitMethod.rawValue

            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.note = trimmedNote.isEmpty ? nil : trimmedNote

            // Delete existing split records
            if let existingSplits = transaction.splits as? Set<TransactionSplit> {
                for split in existingSplits {
                    viewContext.delete(split)
                }
            }

            // Delete existing payer records
            if let existingPayers = transaction.payers as? Set<TransactionPayer> {
                for payer in existingPayers {
                    viewContext.delete(payer)
                }
            }

            // Set legacy payer field
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            if selectedPayerPersons.isEmpty {
                transaction.payer = currentUser
            } else if selectedPayerPersons.count == 1 {
                transaction.payer = selectedPayerPersons.first
            } else {
                if let currentUserPayer = selectedPayerPersons.first(where: { CurrentUser.isCurrentUser($0.id) }) {
                    transaction.payer = currentUserPayer
                } else {
                    transaction.payer = selectedPayerPersons.sorted { ($0.name ?? "") < ($1.name ?? "") }.first
                }
            }

            // Create new TransactionPayer records
            if selectedPayerPersons.isEmpty {
                let payerRecord = TransactionPayer(context: viewContext)
                payerRecord.paidBy = currentUser
                payerRecord.transaction = transaction
                payerRecord.amount = totalAmountDouble
            } else if selectedPayerPersons.count == 1, let singlePayer = selectedPayerPersons.first {
                let payerRecord = TransactionPayer(context: viewContext)
                payerRecord.paidBy = singlePayer
                payerRecord.transaction = transaction
                payerRecord.amount = totalAmountDouble
            } else {
                for person in selectedPayerPersons {
                    let payerRecord = TransactionPayer(context: viewContext)
                    payerRecord.paidBy = person
                    payerRecord.transaction = transaction
                    let amountStr = payerAmounts[person.id ?? UUID()] ?? "0"
                    payerRecord.amount = Double(amountStr) ?? 0
                }
            }

            // Update group
            transaction.group = selectedGroup

            // Create new split records
            for person in selectedParticipants {
                let splitData = TransactionSplit(context: viewContext)
                splitData.owedBy = person
                splitData.transaction = transaction
                splitData.amount = calculateSplit(for: person)

                if let personId = person.id,
                   let rawString = rawInputs[personId],
                   let rawVal = Double(rawString) {
                    splitData.rawAmount = rawVal
                }
            }

            try viewContext.save()
            HapticManager.success()
            completion(true)
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.transactions.error("Failed to update transaction: \(error.localizedDescription)")
            completion(false)
        }
    }
}
