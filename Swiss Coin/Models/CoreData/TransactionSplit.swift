//
//  TransactionSplit.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(TransactionSplit)
public class TransactionSplit: NSManagedObject {

}

extension TransactionSplit {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionSplit> {
        return NSFetchRequest<TransactionSplit>(entityName: "TransactionSplit")
    }

    @NSManaged public var amount: Double
    @NSManaged public var rawAmount: Double
    @NSManaged public var owedBy: Person?
    @NSManaged public var transaction: FinancialTransaction?

}

extension TransactionSplit: Identifiable {

}
