//
//  TransactionPayer.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(TransactionPayer)
public class TransactionPayer: NSManagedObject {

}

extension TransactionPayer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionPayer> {
        return NSFetchRequest<TransactionPayer>(entityName: "TransactionPayer")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var paidBy: Person?
    @NSManaged public var transaction: FinancialTransaction?

}

extension TransactionPayer: Identifiable {

}
