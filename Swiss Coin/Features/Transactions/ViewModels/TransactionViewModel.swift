import Combine
import Contacts
import CoreData
import Foundation
import os
import SwiftUI

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var totalAmount: String = ""
    @Published var date: Date = Date()
    @Published var note: String = ""
    @Published var transactionCurrency: String = UserDefaults.standard.string(forKey: "default_currency") ?? "USD"

    // MARK: - Category Support
    @Published var selectedCategory: Category?

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
    // Map PersonID -> String
    @Published var rawInputs: [UUID: String] = [:]

    // Optional group for group transactions
    var selectedGroup: UserGroup?

    // MARK: - Search Fields
    @Published var paidBySearchText: String = ""
    @Published var splitWithSearchText: String = ""

    // Cached contact/group lists to avoid fetching on every property access
    @Published private(set) var cachedPaidByContacts: [Person] = []
    @Published private(set) var cachedSplitWithContacts: [Person] = []
    @Published private(set) var cachedSplitWithGroups: [UserGroup] = []

    // MARK: - Phone Contacts Integration
    private let contactsManager = ContactsManager()
    @Published var phoneContacts: [ContactsManager.PhoneContact] = []
    private var existingPhoneNumbers: Set<String> = []

    // MARK: - Save State
    @Published var isSaving: Bool = false
    @Published var saveCompleted: Bool = false

    // MARK: - Constants
    static let epsilon: Double = 0.01
    static let percentageTolerance: Double = 0.01
    static let maxAmount: Double = 999_999_999.99

    private var viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.viewContext = context

        // Default payer ("You") should be in the split by default
        let currentUser = CurrentUser.getOrCreate(in: context)
        selectedParticipants.insert(currentUser)

        // Set default category
        selectedCategory = Category.builtIn.first { $0.id == "other" }

        // Initial fetch
        refreshAllContacts()
        refreshAllGroups()

        setupSearchListeners()

        // Fetch phone contacts
        Task { await loadPhoneContacts() }
    }

    /// Convenience initializer for pre-selecting a person as participant
    convenience init(context: NSManagedObjectContext, initialPerson: Person) {
        self.init(context: context)
        selectedParticipants.insert(initialPerson)
    }

    /// Convenience initializer for pre-selecting a group and its members
    convenience init(context: NSManagedObjectContext, initialGroup: UserGroup) {
        self.init(context: context)
        selectedGroup = initialGroup
        if let members = initialGroup.members as? Set<Person> {
            for member in members {
                selectedParticipants.insert(member)
            }
        }
    }

    private func loadPhoneContacts() async {
        if contactsManager.authorizationStatus == .authorized {
            await contactsManager.fetchContacts()
            existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
            phoneContacts = contactsManager.contacts
        }
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
        fetchRequest.fetchLimit = 20
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
        fetchRequest.fetchLimit = 20
        if !query.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        }
        cachedPaidByContacts = (try? viewContext.fetch(fetchRequest)) ?? []
    }

    private func refreshSplitWithContacts(query: String) {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        fetchRequest.fetchLimit = 20
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

    /// Phone contacts filtered for "Paid By" search (excludes already-added persons)
    var filteredPaidByPhoneContacts: [ContactsManager.PhoneContact] {
        guard !paidBySearchText.isEmpty else { return [] }
        let search = paidBySearchText.lowercased()
        return phoneContacts.filter { contact in
            guard contact.fullName.lowercased().contains(search) ||
                  contact.phoneNumbers.contains(where: { $0.contains(search) }) else { return false }
            return !contact.phoneNumbers.contains(where: { phone in
                let normalized = phone.normalizedPhoneNumber()
                return existingPhoneNumbers.contains(normalized) || existingPhoneNumbers.contains(phone)
            })
        }
    }

    /// Phone contacts filtered for "Split With" search (excludes already-added persons)
    var filteredSplitWithPhoneContacts: [ContactsManager.PhoneContact] {
        guard !splitWithSearchText.isEmpty else { return [] }
        let search = splitWithSearchText.lowercased()
        return phoneContacts.filter { contact in
            guard contact.fullName.lowercased().contains(search) ||
                  contact.phoneNumbers.contains(where: { $0.contains(search) }) else { return false }
            return !contact.phoneNumbers.contains(where: { phone in
                let normalized = phone.normalizedPhoneNumber()
                return existingPhoneNumbers.contains(normalized) || existingPhoneNumbers.contains(phone)
            })
        }
    }

    /// Creates a Person from a PhoneContact and adds as participant
    func addPhoneContactAsParticipant(_ contact: ContactsManager.PhoneContact) {
        let person = ContactsManager.getOrCreatePerson(from: contact, in: viewContext)
        do { try viewContext.save() } catch {
            AppLogger.coreData.error("Failed to save phone contact: \(error.localizedDescription)")
        }
        selectedParticipants.insert(person)
        refreshAllContacts()
        existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
        splitWithSearchText = ""
    }

    /// Creates a Person from a PhoneContact and adds as payer
    func addPhoneContactAsPayer(_ contact: ContactsManager.PhoneContact) {
        let person = ContactsManager.getOrCreatePerson(from: contact, in: viewContext)
        do { try viewContext.save() } catch {
            AppLogger.coreData.error("Failed to save phone contact: \(error.localizedDescription)")
        }
        selectedPayerPersons.insert(person)
        if !selectedParticipants.contains(person) {
            selectedParticipants.insert(person)
        }
        refreshAllContacts()
        existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
        paidBySearchText = ""
    }

    // MARK: - Amount Sanitization

    /// Sanitizes amount input to allow only valid decimal characters
    func sanitizeAmountInput(_ input: String) -> String {
        var result = ""
        var hasDecimalPoint = false
        var decimalCount = 0
        let maxDecimals = CurrencyFormatter.isZeroDecimal(transactionCurrency) ? 0 : 2

        for char in input {
            if char.isNumber {
                if hasDecimalPoint {
                    if decimalCount < maxDecimals {
                        result.append(char)
                        decimalCount += 1
                    }
                } else {
                    result.append(char)
                }
            } else if char == "." && !hasDecimalPoint && maxDecimals > 0 {
                hasDecimalPoint = true
                result.append(char)
            }
        }

        // Cap at max amount
        if let value = Double(result), value > Self.maxAmount {
            return String(format: maxDecimals > 0 ? "%.2f" : "%.0f", Self.maxAmount)
        }

        return result
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
            let personId = person.id ?? UUID()
            return sum + (Double(payerAmounts[personId] ?? "0") ?? 0)
        }
    }

    /// Whether paid-by amounts balance with the total transaction amount
    var isPaidByBalanced: Bool {
        if selectedPayerPersons.count <= 1 {
            return true // Single payer auto-fills to total
        }
        return abs(totalPaidByPayers - totalAmountDouble) < Self.epsilon
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

    /// Remaining or excess amount for display
    var balanceRemainingText: String? {
        let balance = totalBalance
        if abs(balance) < Self.epsilon { return nil }
        if balance > 0 {
            return "Remaining: \(CurrencyFormatter.formatAbsolute(balance, currencyCode: transactionCurrency))"
        } else {
            return "Over by: \(CurrencyFormatter.formatAbsolute(balance, currencyCode: transactionCurrency))"
        }
    }

    // MARK: - Validation

    struct ValidationResult {
        let isValid: Bool
        let message: String?
    }

    /// Centralized validation logic — single source of truth
    func validate() -> ValidationResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            return ValidationResult(isValid: false, message: "Please enter a title")
        }
        if totalAmountDouble <= 0 {
            return ValidationResult(isValid: false, message: "Amount must be greater than zero")
        }
        if totalAmountDouble > Self.maxAmount {
            return ValidationResult(isValid: false, message: "Amount exceeds maximum allowed")
        }
        if selectedParticipants.isEmpty {
            return ValidationResult(isValid: false, message: "Select at least one person to split with")
        }

        // Multi-payer validation
        if selectedPayerPersons.count > 1 && !isPaidByBalanced {
            return ValidationResult(isValid: false, message: "Paid-by amounts must equal the total")
        }

        // Split method specific validation
        switch splitMethod {
        case .equal:
            return ValidationResult(isValid: true, message: nil)

        case .percentage:
            let totalPercent = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if abs(totalPercent - 100.0) >= 0.01 {
                return ValidationResult(isValid: false, message: "Percentages must add up to 100%")
            }

        case .amount:
            let totalExact = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if abs(totalExact - totalAmountDouble) >= Self.epsilon {
                return ValidationResult(isValid: false, message: "Amounts must equal the total")
            }

        case .adjustment:
            let totalAdjustments = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if totalAdjustments > totalAmountDouble {
                return ValidationResult(isValid: false, message: "Adjustments cannot exceed the total amount")
            }

        case .shares:
            let totalShares = selectedParticipants.reduce(0.0) { sum, person in
                sum + (Double(rawInputs[person.id ?? UUID()] ?? "0") ?? 0)
            }
            if totalShares <= 0 {
                return ValidationResult(isValid: false, message: "Enter shares for at least one person")
            }
        }

        return ValidationResult(isValid: true, message: nil)
    }

    var isValid: Bool {
        validate().isValid
    }

    var validationMessage: String? {
        validate().message
    }

    // MARK: - Actions

    /// Initialize sensible default raw inputs when switching split methods.
    /// Prevents empty fields when changing between methods.
    func initializeDefaultRawInputs(for method: SplitMethod) {
        rawInputs = [:]
        let count = max(1, selectedParticipants.count)
        for person in selectedParticipants {
            guard let personId = person.id else { continue }
            switch method {
            case .equal:
                break
            case .percentage:
                rawInputs[personId] = String(format: "%.1f", 100.0 / Double(count))
            case .shares:
                rawInputs[personId] = "1"
            case .amount:
                rawInputs[personId] = String(format: "%.2f", totalAmountDouble / Double(count))
            case .adjustment:
                rawInputs[personId] = "0"
            }
        }
    }

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

        guard totalAmountDouble < 10_000_000 else { return 0 }
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

        isSaving = true

        // 2. Trim title
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // 3. Create transaction entity
            let transaction = FinancialTransaction(context: viewContext)
            transaction.id = UUID()
            transaction.title = cleanTitle
            transaction.amount = totalAmountDouble
            transaction.currency = transactionCurrency.isEmpty ? nil : transactionCurrency
            transaction.date = date
            transaction.splitMethod = splitMethod.rawValue

            // Set note — encode category as prefix if present
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            var fullNote = ""
            if let category = selectedCategory {
                fullNote = "[category:\(category.id)]"
            }
            if !trimmedNote.isEmpty {
                fullNote += (fullNote.isEmpty ? "" : " ") + trimmedNote
            }
            transaction.note = fullNote.isEmpty ? nil : fullNote

            // 4. Create payer records
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            createPayerRecords(for: transaction, currentUser: currentUser)

            // 5. Set legacy payer field for backward compatibility
            setLegacyPayer(for: transaction, currentUser: currentUser)

            // 6. Set creator (always the current user)
            transaction.createdBy = currentUser

            // 7. Assign group if this is a group transaction
            if let group = selectedGroup {
                transaction.group = group
            }

            // 8. Create splits for each participant
            for person in selectedParticipants {
                let splitData = TransactionSplit(context: viewContext)
                splitData.id = UUID()
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

            // 9. Save to CoreData
            try viewContext.save()

            // 10. Success feedback
            HapticManager.transactionAdded()
            isSaving = false
            saveCompleted = true

            // 11. Call completion handler
            completion(true)

        } catch {
            // 12. Handle save error
            viewContext.rollback()
            HapticManager.error()
            isSaving = false
            AppLogger.transactions.error("Failed to save transaction: \(error.localizedDescription)")
            completion(false)
        }
    }

    // MARK: - Payer Record Helpers

    private func createPayerRecords(for transaction: FinancialTransaction, currentUser: Person) {
        if selectedPayerPersons.isEmpty {
            // Default: "You" pays the full amount
            let payerRecord = TransactionPayer(context: viewContext)
            payerRecord.id = UUID()
            payerRecord.paidBy = currentUser
            payerRecord.transaction = transaction
            payerRecord.amount = totalAmountDouble
        } else if selectedPayerPersons.count == 1, let singlePayer = selectedPayerPersons.first {
            // Single payer: auto-fill to total
            let payerRecord = TransactionPayer(context: viewContext)
            payerRecord.id = UUID()
            payerRecord.paidBy = singlePayer
            payerRecord.transaction = transaction
            payerRecord.amount = totalAmountDouble
        } else {
            // Multi-payer: use entered amounts
            for person in selectedPayerPersons {
                let payerRecord = TransactionPayer(context: viewContext)
                payerRecord.id = UUID()
                payerRecord.paidBy = person
                payerRecord.transaction = transaction
                let amountStr = payerAmounts[person.id ?? UUID()] ?? "0"
                payerRecord.amount = Double(amountStr) ?? 0
            }
        }
    }

    private func setLegacyPayer(for transaction: FinancialTransaction, currentUser: Person) {
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
    }

    /// Reset the form to default values
    func resetForm() {
        title = ""
        totalAmount = ""
        date = Date()
        note = ""
        transactionCurrency = UserDefaults.standard.string(forKey: "default_currency") ?? "USD"
        selectedCategory = Category.builtIn.first { $0.id == "other" }
        selectedPayerPersons = []
        payerAmounts = [:]
        selectedParticipants = []
        splitMethod = .equal
        rawInputs = [:]
        selectedGroup = nil
        paidBySearchText = ""
        splitWithSearchText = ""
        isSaving = false
        saveCompleted = false

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
        transactionCurrency = transaction.effectiveCurrency

        // Parse note for category prefix
        let rawNote = transaction.note ?? ""
        if rawNote.hasPrefix("[category:") {
            if let endIndex = rawNote.firstIndex(of: "]") {
                let categoryId = String(rawNote[rawNote.index(rawNote.startIndex, offsetBy: 10)..<endIndex])
                selectedCategory = Category.all.first { $0.id == categoryId }
                let remainingNote = String(rawNote[rawNote.index(after: endIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                note = remainingNote
            } else {
                note = rawNote
            }
        } else {
            note = rawNote
        }

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
            transaction.currency = transactionCurrency.isEmpty ? nil : transactionCurrency
            transaction.date = date
            transaction.splitMethod = splitMethod.rawValue

            // Set note with category prefix
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            var fullNote = ""
            if let category = selectedCategory {
                fullNote = "[category:\(category.id)]"
            }
            if !trimmedNote.isEmpty {
                fullNote += (fullNote.isEmpty ? "" : " ") + trimmedNote
            }
            transaction.note = fullNote.isEmpty ? nil : fullNote

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

            // Create new payer records
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            createPayerRecords(for: transaction, currentUser: currentUser)
            setLegacyPayer(for: transaction, currentUser: currentUser)

            // Update group
            transaction.group = selectedGroup

            // Create new split records
            for person in selectedParticipants {
                let splitData = TransactionSplit(context: viewContext)
                splitData.id = UUID()
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
