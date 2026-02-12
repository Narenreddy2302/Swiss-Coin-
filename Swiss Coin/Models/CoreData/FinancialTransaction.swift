//
//  FinancialTransaction.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(FinancialTransaction)
public class FinancialTransaction: NSManagedObject {

}

extension FinancialTransaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FinancialTransaction> {
        return NSFetchRequest<FinancialTransaction>(entityName: "FinancialTransaction")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var splitMethod: String?
    @NSManaged public var note: String?
    @NSManaged public var payer: Person?
    @NSManaged public var createdBy: Person?
    @NSManaged public var group: UserGroup?
    @NSManaged public var splits: NSSet?
    @NSManaged public var payers: NSSet?
    @NSManaged public var comments: NSSet?

}

// MARK: Generated accessors for splits
extension FinancialTransaction {
    @objc(addSplitsObject:)
    @NSManaged public func addToSplits(_ value: TransactionSplit)

    @objc(removeSplitsObject:)
    @NSManaged public func removeFromSplits(_ value: TransactionSplit)

    @objc(addSplits:)
    @NSManaged public func addToSplits(_ values: NSSet)

    @objc(removeSplits:)
    @NSManaged public func removeFromSplits(_ values: NSSet)
}

// MARK: Generated accessors for payers
extension FinancialTransaction {
    @objc(addPayersObject:)
    @NSManaged public func addToPayers(_ value: TransactionPayer)

    @objc(removePayersObject:)
    @NSManaged public func removeFromPayers(_ value: TransactionPayer)

    @objc(addPayers:)
    @NSManaged public func addToPayers(_ values: NSSet)

    @objc(removePayers:)
    @NSManaged public func removeFromPayers(_ values: NSSet)
}

// MARK: Generated accessors for comments
extension FinancialTransaction {
    @objc(addCommentsObject:)
    @NSManaged public func addToComments(_ value: ChatMessage)

    @objc(removeCommentsObject:)
    @NSManaged public func removeFromComments(_ value: ChatMessage)

    @objc(addComments:)
    @NSManaged public func addToComments(_ values: NSSet)

    @objc(removeComments:)
    @NSManaged public func removeFromComments(_ values: NSSet)
}

extension FinancialTransaction: Identifiable {

}

// MARK: - Multi-Payer Utilities
extension FinancialTransaction {

    /// Whether this transaction has multiple payers recorded
    var isMultiPayer: Bool {
        guard let payerSet = payers as? Set<TransactionPayer> else { return false }
        return payerSet.count > 1
    }

    /// Returns all payer contributions. For legacy transactions without TransactionPayer records,
    /// synthesizes a single payer entry from the legacy `payer` relationship.
    var effectivePayers: [(personId: UUID?, amount: Double)] {
        if let payerSet = payers as? Set<TransactionPayer>, !payerSet.isEmpty {
            return payerSet.map { (personId: $0.paidBy?.id, amount: $0.amount) }
        }
        // Legacy fallback: single payer paid the entire amount
        return [(personId: payer?.id, amount: amount)]
    }

    /// Calculate the pairwise balance between two participants in this transaction.
    /// Returns positive if personA is owed by personB, negative if personA owes personB.
    func pairwiseBalance(personA: UUID, personB: UUID) -> Double {
        let splitSet = splits as? Set<TransactionSplit> ?? []
        let payerContributions = effectivePayers

        // Build net positions: net_i = paid_i - owed_i
        var netPositions: [UUID: Double] = [:]

        for (personId, paidAmount) in payerContributions {
            guard let pid = personId else { continue }
            netPositions[pid, default: 0] += paidAmount
        }

        for split in splitSet {
            guard let pid = split.owedBy?.id else { continue }
            netPositions[pid, default: 0] -= split.amount
        }

        let netA = netPositions[personA] ?? 0
        let netB = netPositions[personB] ?? 0

        let totalCredit = netPositions.values.filter { $0 > 0.001 }.reduce(0, +)
        guard totalCredit > 0.001 else { return 0 }

        if netA > 0.001 && netB < -0.001 {
            // B owes A: proportional share of B's debt allocated to A
            return abs(netB) * (netA / totalCredit)
        } else if netA < -0.001 && netB > 0.001 {
            // A owes B: proportional share of A's debt allocated to B
            return -(abs(netA) * (netB / totalCredit))
        }

        return 0
    }
}
