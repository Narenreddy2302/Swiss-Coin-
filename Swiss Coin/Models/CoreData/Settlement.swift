//
//  Settlement.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Settlement)
public class Settlement: NSManagedObject {

}

extension Settlement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Settlement> {
        return NSFetchRequest<Settlement>(entityName: "Settlement")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var note: String?
    @NSManaged public var isFullSettlement: Bool
    @NSManaged public var fromPerson: Person?
    @NSManaged public var toPerson: Person?

}

extension Settlement: Identifiable {

}
