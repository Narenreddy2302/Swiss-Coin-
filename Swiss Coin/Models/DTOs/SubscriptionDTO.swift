//
//  SubscriptionDTO.swift
//  Swiss Coin
//
//  Codable DTOs for `subscriptions`, `subscription_subscribers`,
//  `subscription_payments`, `subscription_settlements`, and
//  `subscription_reminders` Supabase tables.
//

import Foundation

// MARK: - Subscription

struct SubscriptionDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    var name: String
    var amount: Double
    var cycle: String
    var customCycleDays: Int16?
    var startDate: Date
    var nextBillingDate: Date?
    var isShared: Bool
    var isActive: Bool
    var category: String?
    var iconName: String?
    var colorHex: String?
    var notes: String?
    var notificationEnabled: Bool
    var notificationDaysBefore: Int16
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case amount
        case cycle
        case customCycleDays = "custom_cycle_days"
        case startDate = "start_date"
        case nextBillingDate = "next_billing_date"
        case isShared = "is_shared"
        case isActive = "is_active"
        case category
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case notes
        case notificationEnabled = "notification_enabled"
        case notificationDaysBefore = "notification_days_before"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Subscription Subscribers Junction

struct SubscriptionSubscriberDTO: Codable, Sendable {
    let subscriptionId: UUID
    let personId: UUID

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case personId = "person_id"
    }
}

// MARK: - Subscription Payment

struct SubscriptionPaymentDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let subscriptionId: UUID
    let payerId: UUID
    var amount: Double
    var date: Date
    var billingPeriodStart: Date?
    var billingPeriodEnd: Date?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionId = "subscription_id"
        case payerId = "payer_id"
        case amount
        case date
        case billingPeriodStart = "billing_period_start"
        case billingPeriodEnd = "billing_period_end"
        case note
    }
}

// MARK: - Subscription Settlement

struct SubscriptionSettlementDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let subscriptionId: UUID
    let fromPersonId: UUID
    let toPersonId: UUID
    var amount: Double
    var date: Date
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionId = "subscription_id"
        case fromPersonId = "from_person_id"
        case toPersonId = "to_person_id"
        case amount
        case date
        case note
    }
}

// MARK: - Subscription Reminder

struct SubscriptionReminderDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let subscriptionId: UUID
    var createdDate: Date
    let toPersonId: UUID
    var amount: Double
    var message: String?
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionId = "subscription_id"
        case createdDate = "created_date"
        case toPersonId = "to_person_id"
        case amount
        case message
        case isRead = "is_read"
    }
}

// MARK: - CoreData Conversion

extension SubscriptionDTO {
    init(from sub: Subscription, ownerId: UUID) {
        self.id = sub.id ?? UUID()
        self.ownerId = ownerId
        self.name = sub.name ?? ""
        self.amount = sub.amount
        self.cycle = sub.cycle ?? "monthly"
        self.customCycleDays = sub.customCycleDays
        self.startDate = sub.startDate ?? Date()
        self.nextBillingDate = sub.nextBillingDate
        self.isShared = sub.isShared
        self.isActive = sub.isActive
        self.category = sub.category
        self.iconName = sub.iconName
        self.colorHex = sub.colorHex
        self.notes = sub.notes
        self.notificationEnabled = sub.notificationEnabled
        self.notificationDaysBefore = sub.notificationDaysBefore
        self.isArchived = sub.isArchived
        self.createdAt = Date()
        self.updatedAt = sub.updatedAt ?? Date()
        self.deletedAt = sub.deletedAt
    }

    func apply(to sub: Subscription) {
        sub.id = id
        sub.name = name
        sub.amount = amount
        sub.cycle = cycle
        sub.customCycleDays = customCycleDays ?? 0
        sub.startDate = startDate
        sub.nextBillingDate = nextBillingDate
        sub.isShared = isShared
        sub.isActive = isActive
        sub.category = category
        sub.iconName = iconName
        sub.colorHex = colorHex
        sub.notes = notes
        sub.notificationEnabled = notificationEnabled
        sub.notificationDaysBefore = notificationDaysBefore
        sub.isArchived = isArchived
        sub.updatedAt = updatedAt
        sub.deletedAt = deletedAt
    }
}

extension SubscriptionPaymentDTO {
    init(from payment: SubscriptionPayment) {
        self.id = payment.id ?? UUID()
        self.subscriptionId = payment.subscription?.id ?? UUID()
        self.payerId = payment.payer?.id ?? UUID()
        self.amount = payment.amount
        self.date = payment.date ?? Date()
        self.billingPeriodStart = payment.billingPeriodStart
        self.billingPeriodEnd = payment.billingPeriodEnd
        self.note = payment.note
    }

    func apply(to payment: SubscriptionPayment) {
        payment.id = id
        payment.amount = amount
        payment.date = date
        payment.billingPeriodStart = billingPeriodStart
        payment.billingPeriodEnd = billingPeriodEnd
        payment.note = note
    }
}

extension SubscriptionSettlementDTO {
    init(from settlement: SubscriptionSettlement) {
        self.id = settlement.id ?? UUID()
        self.subscriptionId = settlement.subscription?.id ?? UUID()
        self.fromPersonId = settlement.fromPerson?.id ?? UUID()
        self.toPersonId = settlement.toPerson?.id ?? UUID()
        self.amount = settlement.amount
        self.date = settlement.date ?? Date()
        self.note = settlement.note
    }

    func apply(to settlement: SubscriptionSettlement) {
        settlement.id = id
        settlement.amount = amount
        settlement.date = date
        settlement.note = note
    }
}

extension SubscriptionReminderDTO {
    init(from reminder: SubscriptionReminder) {
        self.id = reminder.id ?? UUID()
        self.subscriptionId = reminder.subscription?.id ?? UUID()
        self.createdDate = reminder.createdDate ?? Date()
        self.toPersonId = reminder.toPerson?.id ?? UUID()
        self.amount = reminder.amount
        self.message = reminder.message
        self.isRead = reminder.isRead
    }

    func apply(to reminder: SubscriptionReminder) {
        reminder.id = id
        reminder.createdDate = createdDate
        reminder.amount = amount
        reminder.message = message
        reminder.isRead = isRead
    }
}
