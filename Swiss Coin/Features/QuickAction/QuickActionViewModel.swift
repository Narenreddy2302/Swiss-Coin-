//
//  QuickActionViewModel.swift
//  Swiss Coin
//
//  ViewModel for the Quick Action Transaction flow.
//

import Combine
import CoreData
import os
import SwiftUI

@MainActor
class QuickActionViewModel: ObservableObject {

    // MARK: - Core Data

    private var viewContext: NSManagedObjectContext

    // MARK: - Sheet State

    @Published var isSheetPresented: Bool = false {
        didSet {
            if !isSheetPresented {
                resetForm()
            }
        }
    }

    @Published var currentStep: Int = 1

    /// Number of steps in the flow: 2 for personal transactions, 3 for split
    var totalSteps: Int {
        isSplit ? 3 : 2
    }

    // MARK: - Step 1: Basic Transaction Details

    @Published var amountString: String = ""
    @Published var selectedCurrency: Currency = Currency.fromGlobalSetting()
    @Published var transactionName: String = ""
    @Published var transactionDate: Date = Date()
    @Published var selectedCategory: Category? = nil

    @Published var showCurrencyPicker: Bool = false
    @Published var showCategoryPicker: Bool = false

    // MARK: - Step 2: Split Configuration

    @Published var isSplit: Bool = false {
        didSet {
            if !isSplit {
                splitDetails = [:]
                splitMethod = .equal
            }
        }
    }

    // Payer: nil represents "Me" (Current User)
    @Published var paidByPerson: Person? = nil

    // Participants: Set of Persons involved. Does NOT include "Me" implicitly,
    // but we will manage "Me" separate or included?
    // Reference had `participantIds` including "u1" (Me).
    // Let's explicitly include "Me" in this set if they are part of the split.
    // However, `Person` entity usually doesn't exist for "Me".
    // So we will use a mixed approach:
    // `participants` set contains OTHER people.
    // `isCurrentUserIncluded` boolean?
    // Or better: `splitDetails` keys can be UUIDs. "Me" can have a fixed UUID or specific key.

    // Let's use a wrapper helper to identify participants.
    // But for simplicity, let's say "Me" is always a participant if not specified otherwise?
    // Actually the reference allows toggling "You" in the list.

    // To properly support "Me" which isn't in CoreData Person list usually:
    // We use the centralized CurrentUser.currentUserId for consistency across the app.
    var currentUserUUID: UUID {
        if let id = CurrentUser.currentUserId {
            return id
        }
        // Stable fallback: read or create a persistent UUID in UserDefaults
        let key = "stable_current_user_uuid"
        if let stored = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let newId = UUID()
        UserDefaults.standard.set(newId.uuidString, forKey: key)
        return newId
    }

    @Published var participantIds: Set<UUID> = []

    @Published var selectedGroup: UserGroup? = nil

    // MARK: - Step 2: Search States

    @Published var paidBySearchText: String = ""
    @Published var isPaidBySearchFocused: Bool = false

    @Published var splitWithSearchText: String = ""
    @Published var isSplitWithSearchFocused: Bool = false

    // MARK: - Step 3: Split Method Details

    @Published var splitMethod: SplitMethod = .equal
    @Published var splitDetails: [UUID: SplitDetail] = [:]

    // MARK: - Data Source

    @Published var allPeople: [Person] = []
    @Published var allGroups: [UserGroup] = []

    // MARK: - Init

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchData()

        // Default participant is Me
        participantIds.insert(currentUserUUID)
    }
    
    func setup(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchData()
    }

    /// Convenience initializer for pre-selecting a person
    convenience init(context: NSManagedObjectContext, initialPerson: Person) {
        self.init(context: context)
        // Pre-select the person as a participant and enable split mode
        if let id = initialPerson.id {
            participantIds.insert(id)
        }
        isSplit = true
    }

    /// Convenience initializer for pre-selecting a group
    convenience init(context: NSManagedObjectContext, initialGroup: UserGroup) {
        self.init(context: context)
        // Pre-select the group and add all members
        selectedGroup = initialGroup
        if let members = initialGroup.members as? Set<Person> {
            for member in members {
                if let id = member.id {
                    participantIds.insert(id)
                }
            }
        }
        isSplit = true
    }

    func fetchData() {
        let personRequest: NSFetchRequest<Person> = Person.fetchRequest()
        personRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]

        let groupRequest: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        groupRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]

        do {
            allPeople = try viewContext.fetch(personRequest)
            allGroups = try viewContext.fetch(groupRequest)
        } catch {
            AppLogger.coreData.error("Failed to fetch data: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties

    var amount: Double {
        Double(amountString) ?? 0
    }

    func getPerson(byId id: UUID) -> Person? {
        if id == currentUserUUID { return nil }
        return allPeople.first { $0.id == id }
    }

    func getName(for id: UUID) -> String {
        if id == currentUserUUID { return "You" }
        return getPerson(byId: id)?.name ?? "Unknown"
    }

    func getInitials(for id: UUID) -> String {
        if id == currentUserUUID { return "ME" }
        return getPerson(byId: id)?.initials ?? "?"
    }

    var paidByName: String {
        if let person = paidByPerson {
            return person.name ?? "Unknown"
        }
        return "You"
    }

    var canProceedStep1: Bool {
        amount > 0 && !transactionName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canProceedStep2: Bool {
        !isSplit || participantIds.count >= 2
    }

    var canSubmit: Bool {
        guard isSplit else { return true }

        switch splitMethod {
        case .percentage:
            let total = participantIds.reduce(0.0) { sum, id in
                sum + (splitDetails[id]?.percentage ?? 0)
            }
            return abs(total - 100) < 0.1

        case .amount:
            let total = participantIds.reduce(0.0) { sum, id in
                sum + (splitDetails[id]?.amount ?? 0)
            }
            return abs(total - amount) < 0.01

        case .adjustment:
            // Ensure no participant ends up with a negative amount
            let splits = calculateSplits()
            return splits.values.allSatisfy { $0.amount >= 0 }

        default:
            return true
        }
    }

    var totalPercentage: Double {
        participantIds.reduce(0.0) { sum, id in
            sum + (splitDetails[id]?.percentage ?? 0)
        }
    }

    var totalSplitAmount: Double {
        let splits = calculateSplits()
        return splits.values.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Search Filtering

    var filteredPaidByContacts: [Person] {
        guard !paidBySearchText.isEmpty else { return allPeople }
        let search = paidBySearchText.lowercased()
        return allPeople.filter { person in
            (person.name?.lowercased().contains(search) ?? false)
        }
    }

    var filteredSplitWithContacts: [Person] {
        guard !splitWithSearchText.isEmpty else { return allPeople }
        let search = splitWithSearchText.lowercased()
        return allPeople.filter { person in
            (person.name?.lowercased().contains(search) ?? false)
        }
    }

    var filteredSplitWithGroups: [UserGroup] {
        guard !splitWithSearchText.isEmpty else { return allGroups }
        let search = splitWithSearchText.lowercased()
        return allGroups.filter { group in
            (group.name?.lowercased().contains(search) ?? false)
        }
    }

    // MARK: - Actions

    func openSheet() {
        isSheetPresented = true
        fetchData()  // Refresh data
    }

    func closeSheet() {
        isSheetPresented = false
        // resetForm call via didSet
    }

    func resetForm() {
        currentStep = 1
        amountString = ""
        selectedCurrency = Currency.fromGlobalSetting()
        transactionName = ""
        transactionDate = Date()
        selectedCategory = nil
        showCurrencyPicker = false
        showCategoryPicker = false
        isSplit = false

        paidByPerson = nil  // Me
        participantIds = [currentUserUUID]
        selectedGroup = nil

        paidBySearchText = ""
        isPaidBySearchFocused = false
        splitWithSearchText = ""
        isSplitWithSearchFocused = false

        splitMethod = .equal
        splitDetails = [:]
    }

    func nextStep() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }

    /// Quick action: split the transaction equally and save immediately.
    /// If only the current user is a participant, saves as a personal transaction.
    func splitEqualAndSave() {
        if participantIds.count > 1 {
            isSplit = true
            splitMethod = .equal
        } else {
            isSplit = false
        }
        saveTransaction()
    }

    /// Navigate to Step 3 for advanced split configuration.
    /// Requires at least 2 participants for a meaningful split.
    func goToMoreOptions() {
        guard participantIds.count >= 2 else {
            errorMessage = "Add at least one other person to configure split options"
            showingError = true
            HapticManager.error()
            return
        }
        isSplit = true  // Makes totalSteps = 3 so nextStep() can proceed
        nextStep()
    }

    func selectPayer(_ person: Person?) {
        paidByPerson = person
        paidBySearchText = ""
        isPaidBySearchFocused = false

        // Ensure payer is participant
        let id = person?.id ?? currentUserUUID
        if !participantIds.contains(id) {
            participantIds.insert(id)
        }
    }

    func toggleParticipant(_ id: UUID) {
        if id == currentUserUUID && participantIds.contains(currentUserUUID)
            && participantIds.count == 1
        {
            return  // Can't remove self if only one
        }

        if participantIds.contains(id) {
            participantIds.remove(id)
            splitDetails.removeValue(forKey: id)
            selectedGroup = nil

            // Reset payer if the removed participant was the current payer
            if let payer = paidByPerson, payer.id == id {
                paidByPerson = nil
            }
        } else {
            participantIds.insert(id)
        }
    }

    func selectGroup(_ group: UserGroup) {
        selectedGroup = group

        // Add all group members as participants
        if let members = group.members as? Set<Person> {
            for member in members {
                if let id = member.id {
                    participantIds.insert(id)
                }
            }
        }

        splitWithSearchText = ""
        isSplitWithSearchFocused = false
    }

    func clearSelectedGroup() {
        selectedGroup = nil
    }

    func addParticipantFromSearch(_ person: Person) {
        if let id = person.id {
            participantIds.insert(id)
        }
        splitWithSearchText = ""
        isSplitWithSearchFocused = false
    }

    func updateSplitDetail(
        userId: UUID, amount: Double? = nil, percentage: Double? = nil, shares: Int? = nil,
        adjustment: Double? = nil
    ) {
        var detail = splitDetails[userId] ?? SplitDetail()

        if let amount = amount { detail.amount = amount }
        if let percentage = percentage { detail.percentage = percentage }
        if let shares = shares { detail.shares = shares }
        if let adjustment = adjustment { detail.adjustment = adjustment }

        splitDetails[userId] = detail
    }

    func calculateSplits() -> [UUID: SplitDetail] {
        let total = amount
        let count = Double(participantIds.count)

        guard count > 0 && total > 0 else { return [:] }

        var result: [UUID: SplitDetail] = [:]

        switch splitMethod {
        case .equal:
            let equalShare = total / count
            let percentage = 100.0 / count
            for userId in participantIds {
                result[userId] = SplitDetail(
                    amount: equalShare, percentage: percentage, shares: 1, adjustment: 0)
            }

        case .amount:
            for userId in participantIds {
                let customAmount = splitDetails[userId]?.amount ?? 0
                let percentage = total > 0 ? (customAmount / total) * 100 : 0
                result[userId] = SplitDetail(
                    amount: customAmount, percentage: percentage, shares: 1, adjustment: 0)
            }

        case .percentage:
            for userId in participantIds {
                let percentage = splitDetails[userId]?.percentage ?? 0
                let calculatedAmount = (percentage / 100.0) * total
                result[userId] = SplitDetail(
                    amount: calculatedAmount, percentage: percentage, shares: 1, adjustment: 0)
            }

        case .shares:
            let totalShares = participantIds.reduce(0) { sum, id in
                sum + (splitDetails[id]?.shares ?? 1)
            }
            guard totalShares > 0 else {
                // Fallback to equal split if all shares are zero
                let equalShare = total / count
                for userId in participantIds {
                    result[userId] = SplitDetail(amount: equalShare, percentage: 100.0 / count, shares: 1, adjustment: 0)
                }
                return result
            }

            for userId in participantIds {
                let shares = splitDetails[userId]?.shares ?? 1
                let shareAmount = (Double(shares) / Double(totalShares)) * total
                let percentage = (Double(shares) / Double(totalShares)) * 100
                result[userId] = SplitDetail(
                    amount: shareAmount, percentage: percentage, shares: shares, adjustment: 0)
            }

        case .adjustment:
            let totalAdjustments = participantIds.reduce(0.0) { sum, id in
                sum + (splitDetails[id]?.adjustment ?? 0)
            }
            let adjustedBase = (total - totalAdjustments) / count

            for userId in participantIds {
                let adjustment = splitDetails[userId]?.adjustment ?? 0
                let finalAmount = adjustedBase + adjustment
                let percentage = total > 0 ? (finalAmount / total) * 100 : 0
                result[userId] = SplitDetail(
                    amount: finalAmount, percentage: percentage, shares: 1, adjustment: adjustment)
            }
        }

        return result
    }

    // MARK: - Error State

    @Published var showingError = false
    @Published var errorMessage = ""

    // MARK: - Submission

    func saveTransaction() {
        // Validate amount
        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero"
            showingError = true
            return
        }

        // Validate transaction name
        guard !transactionName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a transaction name"
            showingError = true
            return
        }

        let splits = calculateSplits()

        // Get or create current user for proper payer reference
        let currentUser = CurrentUser.getOrCreate(in: viewContext)

        let transaction = FinancialTransaction(context: viewContext)
        transaction.id = UUID()
        transaction.title = transactionName.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.amount = amount
        transaction.date = transactionDate
        // Payer: Use current user if paidByPerson is nil
        transaction.payer = paidByPerson ?? currentUser
        // Creator: Always the current user
        transaction.createdBy = currentUser
        transaction.splitMethod = splitMethod.rawValue
        transaction.group = selectedGroup

        if isSplit {
            for (userId, detail) in splits {
                // Create TransactionSplit entity
                let split = TransactionSplit(context: viewContext)
                split.transaction = transaction
                split.amount = detail.amount

                if userId == currentUserUUID {
                    // Current user's share of the expense
                    split.owedBy = currentUser
                } else if let person = getPerson(byId: userId) {
                    split.owedBy = person
                } else {
                    AppLogger.transactions.warning("Could not find person with ID \(userId)")
                    continue
                }
            }
        }
        // Non-split (personal) transactions: no TransactionSplit records needed.
        // Creating a split where the payer owes themselves skews balance calculations.

        do {
            try viewContext.save()
            HapticManager.success()
            closeSheet()
        } catch {
            // Rollback failed changes
            viewContext.rollback()
            
            HapticManager.error()
            errorMessage = "Failed to save transaction. Please try again."
            showingError = true
            AppLogger.transactions.error("Failed to create transaction: \(error.localizedDescription)")
        }
    }
}
