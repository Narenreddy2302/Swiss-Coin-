//
//  Settlement.swift
//  Swiss Coin
//

import CoreData
import Foundation

@objc(Settlement)
public class Settlement: NSManagedObject {
    override public func willSave() {
        super.willSave()
        if hasChanges && !isDeleted {
            let now = Date()
            let current = primitiveValue(forKey: "updatedAt") as? Date
            if current == nil || now.timeIntervalSince(current!) > 1 {
                setPrimitiveValue(now, forKey: "updatedAt")
            }
        }
    }
}

extension Settlement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Settlement> {
        return NSFetchRequest<Settlement>(entityName: "Settlement")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var currency: String?
    @NSManaged public var date: Date?
    @NSManaged public var note: String?
    @NSManaged public var isFullSettlement: Bool
    @NSManaged public var updatedAt: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var isShared: Bool
    @NSManaged public var sharingStatus: String?
    @NSManaged public var sharedByProfileId: UUID?
    @NSManaged public var fromPerson: Person?
    @NSManaged public var toPerson: Person?

}

// MARK: - Currency Utilities
extension Settlement {

    /// Returns the currency code for this settlement, or the global default for legacy records.
    var effectiveCurrency: String {
        if let code = currency, !code.isEmpty { return code }
        return UserDefaults.standard.string(forKey: "default_currency") ?? "USD"
    }
}

extension Settlement: Identifiable {

}
