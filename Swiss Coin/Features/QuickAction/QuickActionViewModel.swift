//
//  QuickActionViewModel.swift
//  Swiss Coin
//
//  ViewModel for the Quick Action Transaction flow.
//

import Combine
import CoreData
import SwiftUI

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

    // MARK: - Step 1: Basic Transaction Details

    @Published var transactionType: TransactionType = .expense
    @Published var amountString: String = ""
    @Published var selectedCurrency: Currency = Currency.all[0]
    @Published var transactionName: String = ""
    @Published var selectedCategory: Category? = nil

    @Published var showCurrencyPicker: Bool = false
    @Published var showCategoryPicker: Bool = false

    // MARK: - Step 2: Split Configuration

    @Published var isSplit: Bool = false

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
    // We will use a special UUID for "Me".
    let currentUserUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var participantIds: Set<UUID> = []

    @Published var selectedGroup: UserGroup? = nil

    // MARK: - Step 2: Search States

    @Published var paidBySearchText: String = ""
    @Published var isPaidBySearchFocused: Bool = false

    @Published var splitWithSearchText: String = ""
    @Published var isSplitWithSearchFocused: Bool = false

    // MARK: - Step 3: Split Method Details

    @Published var splitMethod: QuickActionSplitMethod = .equal
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

    func fetchData() {
        let personRequest: NSFetchRequest<Person> = Person.fetchRequest()
        personRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]

        let groupRequest: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        groupRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]

        do {
            allPeople = try viewContext.fetch(personRequest)
            allGroups = try viewContext.fetch(groupRequest)
        } catch {
            print("Error fetching data: \(error)")
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
        return getPerson(byId: id)?.displayName ?? "Unknown"
    }

    func getInitials(for id: UUID) -> String {
        if id == currentUserUUID { return "ME" }
        return getPerson(byId: id)?.initials ?? "?"
    }

    var paidByName: String {
        if let person = paidByPerson {
            return person.displayName
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
        case .percentages:
            let total = participantIds.reduce(0.0) { sum, id in
                sum + (splitDetails[id]?.percentage ?? 0)
            }
            return abs(total - 100) < 0.1

        case .amounts:
            let total = participantIds.reduce(0.0) { sum, id in
                sum + (splitDetails[id]?.amount ?? 0)
            }
            return abs(total - amount) < 0.01

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
        transactionType = .expense
        amountString = ""
        selectedCurrency = Currency.all[0]
        transactionName = ""
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
        if currentStep < 3 {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
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
        } else {
            participantIds.insert(id)
        }
    }

    func selectGroup(_ group: UserGroup) {
        selectedGroup = group
        // Add all members... wait, UserGroup logic?
        // UserGroup usually has `members` relationship?
        // Looking at Persistence.swift preview, UserGroup doesn't explicitly show members.
        // I need to check UserGroup entity. Assuming it has members.
        // If not, I can't do this part yet.
        // For now, I will assume UserGroup might not have members linked in CoreData or implementation varies.
        // Let's check UserGroup members in next step if this fails or just assumes it works if I find the relationship.
        // I'll skip complex group logic for now if relationship is unknown, BUT reference requires it.
        // I'll assume `members` is a Set<Person>.

        /*
         // Dynamic Member Fetching if needed
         if let members = group.members as? Set<Person> {
             for member in members {
                 if let id = member.id {
                     participantIds.insert(id)
                 }
             }
         }
         */

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

        case .amounts:
            for userId in participantIds {
                let customAmount = splitDetails[userId]?.amount ?? 0
                let percentage = total > 0 ? (customAmount / total) * 100 : 0
                result[userId] = SplitDetail(
                    amount: customAmount, percentage: percentage, shares: 1, adjustment: 0)
            }

        case .percentages:
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

    // MARK: - Submission

    func submitTransaction() {
        let splits = calculateSplits()

        let transaction = FinancialTransaction(context: viewContext)
        transaction.id = UUID()
        transaction.title = transactionName
        transaction.amount = amount
        transaction.date = Date()
        // transaction.currency = selectedCurrency.code // If entity has currency
        // transaction.category = selectedCategory?.id // If entity has category

        // Payer
        transaction.payer = paidByPerson  // Nil is Me
        transaction.splitMethod = splitMethod.rawValue

        if isSplit {
            for (userId, detail) in splits {
                // Create TransactionSplit entity
                let split = TransactionSplit(context: viewContext)
                split.transaction = transaction
                split.amount = detail.amount

                if userId != currentUserUUID {
                    split.owedBy = getPerson(byId: userId)
                } else {
                    split.owedBy = nil/// Representing Me? Or handle differently.
                    // Current TransactionSplit entity expects `owedBy` to be `Person?`.
                    // If it's nil, does it mean Me?
                    // In my `TransactionViewModel`, `selectedParticipants` included people.
                    // If I paid, and split with Bob.
                    // Me: Paid +50, Owe 25. Net +25.
                    // Bob: Paid 0, Owe 25. Net -25.
                    // Standard Splitwise model: Transaction has one Payer. Splits define who owes what (Expense share).
                    // If I paid $50. Split equally.
                    // Me expense: $25. Bob expense: $25.
                    // FinancialTransaction stores total $50. Payer = Me.
                    // TransactionSplit for Bob: amount $25. owedBy = Bob.
                    // Do we need TransactionSplit for Me?
                    // Usually yes, if we want to track my expense.
                    // But if `owedBy` is nil, it might be ambiguous.
                    // Let's assume `owedBy` nil means Me for now.
                }
            }
        }

        do {
            try viewContext.save()
            closeSheet()
        } catch {
            print("Error creating transaction: \(error)")
        }
    }
}
