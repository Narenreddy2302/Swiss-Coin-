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
    @NSManaged public var payer: Person?
    @NSManaged public var createdBy: Person?
    @NSManaged public var group: UserGroup?
    @NSManaged public var splits: NSSet?

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

extension FinancialTransaction: Identifiable {

}
