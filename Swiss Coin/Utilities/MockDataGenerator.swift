//
//  MockDataGenerator.swift
//  Swiss Coin
//
//  Centralized mock data generator for development and testing.
//  All mock data is created here and can be easily toggled on/off or removed.
//

import CoreData
import Foundation

// MARK: - Configuration

struct MockDataConfig {
    /// Master toggle for all mock data - set to false to disable seeding
    static var isEnabled: Bool = true

    /// Whether to seed mock data on app launch
    static var seedOnLaunch: Bool = true
}

// MARK: - Mock Data Generator

struct MockDataGenerator {

    // MARK: - Main Entry Point

    /// Seeds all mock data into the provided context
    /// - Parameter context: The managed object context to seed data into
    static func seed(context: NSManagedObjectContext) {
        guard MockDataConfig.isEnabled else { return }
        guard !hasExistingData(context: context) else { return }

        // Create in order of dependencies
        let currentUser = createCurrentUser(context: context)
        let people = createPeople(context: context)
        let groups = createGroups(context: context, people: people, currentUser: currentUser)
        createTransactions(context: context, people: people, groups: groups, currentUser: currentUser)
        createSettlements(context: context, people: people, currentUser: currentUser)
        createReminders(context: context, people: people, currentUser: currentUser)
        createChatMessages(context: context, people: people, groups: groups, currentUser: currentUser)
        createSubscriptions(context: context, people: people, currentUser: currentUser)

        saveContext(context)
    }

    // MARK: - Cleanup Functions

    /// Clears all mock data from the context
    /// - Parameter context: The managed object context to clear
    static func clearAllData(context: NSManagedObjectContext) {
        // Delete all entities in reverse dependency order
        deleteAll(entityName: "TransactionSplit", context: context)
        deleteAll(entityName: "FinancialTransaction", context: context)
        deleteAll(entityName: "Settlement", context: context)
        deleteAll(entityName: "Reminder", context: context)
        deleteAll(entityName: "ChatMessage", context: context)
        deleteAll(entityName: "Subscription", context: context)
        deleteAll(entityName: "UserGroup", context: context)
        deleteAll(entityName: "Person", context: context)
        saveContext(context)
    }

    /// Clears and re-seeds all mock data
    /// - Parameter context: The managed object context to reseed
    static func reseed(context: NSManagedObjectContext) {
        clearAllData(context: context)
        MockDataConfig.isEnabled = true
        seed(context: context)
    }

    // MARK: - Private Helpers

    private static func hasExistingData(context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.fetchLimit = 1
        return (try? context.count(for: fetchRequest)) ?? 0 > 0
    }

    private static func deleteAll(entityName: String, context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? context.execute(deleteRequest)
    }

    private static func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            print("MockDataGenerator: Failed to save context - \(error)")
        }
    }

    private static func date(daysAgo: Int, hoursAgo: Int = 0) -> Date {
        let calendar = Calendar.current
        var date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        date = calendar.date(byAdding: .hour, value: -hoursAgo, to: date) ?? date
        return date
    }

    // MARK: - Current User Creation

    private static func createCurrentUser(context: NSManagedObjectContext) -> Person {
        let currentUser = Person(context: context)
        currentUser.id = CurrentUser.uuid
        currentUser.name = CurrentUser.displayName
        currentUser.colorHex = CurrentUser.defaultColorHex
        return currentUser
    }

    // MARK: - People Creation

    private static func createPeople(context: NSManagedObjectContext) -> [String: Person] {
        let peopleData: [(name: String, color: String, phone: String)] = [
            ("Alex Johnson", "#007AFF", "+1 555-0101"),
            ("Sarah Chen", "#FF9500", "+1 555-0102"),
            ("Mike Williams", "#5856D6", "+1 555-0103"),
            ("Emma Davis", "#FF2D55", "+1 555-0104"),
            ("Nick Thompson", "#34C759", "+1 555-0105"),
            ("David Kim", "#AF52DE", "+1 555-0106")
        ]

        var people: [String: Person] = [:]
        for data in peopleData {
            let person = Person(context: context)
            person.id = UUID()
            person.name = data.name
            person.colorHex = data.color
            person.phoneNumber = data.phone
            people[data.name] = person
        }
        return people
    }

    // MARK: - Groups Creation

    private static func createGroups(
        context: NSManagedObjectContext,
        people: [String: Person],
        currentUser: Person
    ) -> [String: UserGroup] {
        var groups: [String: UserGroup] = [:]

        // Roommates group
        let roommates = UserGroup(context: context)
        roommates.id = UUID()
        roommates.name = "Roommates"
        roommates.colorHex = "#FF9500"
        roommates.createdDate = date(daysAgo: 60)
        roommates.addToMembers(currentUser)
        if let sarah = people["Sarah Chen"] { roommates.addToMembers(sarah) }
        if let alex = people["Alex Johnson"] { roommates.addToMembers(alex) }
        groups["Roommates"] = roommates

        // Work Lunch Crew
        let workLunch = UserGroup(context: context)
        workLunch.id = UUID()
        workLunch.name = "Work Lunch Crew"
        workLunch.colorHex = "#5856D6"
        workLunch.createdDate = date(daysAgo: 45)
        workLunch.addToMembers(currentUser)
        if let mike = people["Mike Williams"] { workLunch.addToMembers(mike) }
        if let emma = people["Emma Davis"] { workLunch.addToMembers(emma) }
        if let nick = people["Nick Thompson"] { workLunch.addToMembers(nick) }
        groups["Work Lunch Crew"] = workLunch

        // Road Trip 2024
        let roadTrip = UserGroup(context: context)
        roadTrip.id = UUID()
        roadTrip.name = "Road Trip 2024"
        roadTrip.colorHex = "#007AFF"
        roadTrip.createdDate = date(daysAgo: 30)
        roadTrip.addToMembers(currentUser)
        if let alex = people["Alex Johnson"] { roadTrip.addToMembers(alex) }
        if let nick = people["Nick Thompson"] { roadTrip.addToMembers(nick) }
        if let sarah = people["Sarah Chen"] { roadTrip.addToMembers(sarah) }
        if let david = people["David Kim"] { roadTrip.addToMembers(david) }
        if let emma = people["Emma Davis"] { roadTrip.addToMembers(emma) }
        groups["Road Trip 2024"] = roadTrip

        return groups
    }

    // MARK: - Transactions Creation

    private static func createTransactions(
        context: NSManagedObjectContext,
        people: [String: Person],
        groups: [String: UserGroup],
        currentUser: Person
    ) {
        let alex = people["Alex Johnson"]!
        let sarah = people["Sarah Chen"]!
        let mike = people["Mike Williams"]!
        let emma = people["Emma Davis"]!
        let nick = people["Nick Thompson"]!
        let david = people["David Kim"]!

        let roommates = groups["Roommates"]
        let workLunch = groups["Work Lunch Crew"]
        let roadTrip = groups["Road Trip 2024"]

        // MARK: Today (0 days ago)
        createTransaction(
            context: context,
            title: "Morning Coffee",
            amount: 12.50,
            daysAgo: 0,
            hoursAgo: 2,
            payer: currentUser,
            participants: [currentUser, alex],
            splitMethod: "Equal"
        )

        // MARK: Yesterday (1 day ago)
        createTransaction(
            context: context,
            title: "Team Lunch at Chipotle",
            amount: 85.00,
            daysAgo: 1,
            payer: mike,
            participants: [currentUser, mike, emma, nick],
            splitMethod: "Equal",
            group: workLunch
        )

        // MARK: 2 days ago
        createTransaction(
            context: context,
            title: "Uber to Airport",
            amount: 45.00,
            daysAgo: 2,
            payer: alex,
            participants: [currentUser, alex],
            splitMethod: "Equal"
        )

        // MARK: 3 days ago
        createTransaction(
            context: context,
            title: "Grocery Run - Whole Foods",
            amount: 156.78,
            daysAgo: 3,
            payer: currentUser,
            participants: [currentUser, sarah],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 4 days ago
        createTransaction(
            context: context,
            title: "Netflix Monthly",
            amount: 22.99,
            daysAgo: 4,
            payer: sarah,
            participants: [currentUser, sarah, alex],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 5 days ago
        createTransaction(
            context: context,
            title: "Birthday Dinner - Olive Garden",
            amount: 220.00,
            daysAgo: 5,
            payer: currentUser,
            participants: [currentUser, alex, sarah, mike, emma],
            splitMethod: "Equal"
        )

        // MARK: 6 days ago
        createTransaction(
            context: context,
            title: "Gas Station Fill-up",
            amount: 65.00,
            daysAgo: 6,
            payer: nick,
            participants: [currentUser, nick],
            splitMethod: "Equal"
        )

        // MARK: 7 days ago
        createTransaction(
            context: context,
            title: "Concert Tickets - Taylor Swift",
            amount: 450.00,
            daysAgo: 7,
            payer: currentUser,
            participants: [currentUser, alex, nick],
            splitMethod: "Amounts"
        )

        // MARK: 10 days ago
        createTransaction(
            context: context,
            title: "Electricity Bill - January",
            amount: 180.00,
            daysAgo: 10,
            payer: sarah,
            participants: [currentUser, sarah],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 12 days ago
        createTransaction(
            context: context,
            title: "Gym Membership",
            amount: 120.00,
            daysAgo: 12,
            payer: currentUser,
            participants: [currentUser],
            splitMethod: "Equal"
        )

        // MARK: 14 days ago
        createTransaction(
            context: context,
            title: "Airbnb - Lake Tahoe Weekend",
            amount: 850.00,
            daysAgo: 14,
            payer: alex,
            participants: [currentUser, alex, nick, sarah, david, emma],
            splitMethod: "Equal",
            group: roadTrip
        )

        // MARK: 15 days ago
        createTransaction(
            context: context,
            title: "Escape Room Team Building",
            amount: 180.00,
            daysAgo: 15,
            payer: mike,
            participants: [currentUser, mike, emma, nick],
            splitMethod: "Equal",
            group: workLunch
        )

        // MARK: 16 days ago
        createTransaction(
            context: context,
            title: "Wine Tasting - Napa Valley",
            amount: 320.00,
            daysAgo: 16,
            payer: currentUser,
            participants: [currentUser, alex, sarah],
            splitMethod: "Equal",
            group: roadTrip
        )

        // MARK: 17 days ago
        createTransaction(
            context: context,
            title: "Ski Equipment Rental",
            amount: 450.00,
            daysAgo: 17,
            payer: nick,
            participants: [currentUser, nick, alex],
            splitMethod: "Percentages",
            group: roadTrip
        )

        // MARK: 18 days ago
        createTransaction(
            context: context,
            title: "Pet Supplies - PetSmart",
            amount: 78.45,
            daysAgo: 18,
            payer: currentUser,
            participants: [currentUser],
            splitMethod: "Equal"
        )

        // MARK: 19 days ago
        createTransaction(
            context: context,
            title: "Amazon Prime Annual",
            amount: 139.00,
            daysAgo: 19,
            payer: currentUser,
            participants: [currentUser, sarah],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 20 days ago
        createTransaction(
            context: context,
            title: "Doctor Visit Co-pay",
            amount: 50.00,
            daysAgo: 20,
            payer: currentUser,
            participants: [currentUser],
            splitMethod: "Equal"
        )

        // MARK: 21 days ago
        createTransaction(
            context: context,
            title: "Flight Tickets - NYC Trip",
            amount: 770.00,
            daysAgo: 21,
            payer: currentUser,
            participants: [currentUser, alex],
            splitMethod: "Equal"
        )

        // MARK: 22 days ago
        createTransaction(
            context: context,
            title: "Sushi Dinner - Nobu",
            amount: 280.00,
            daysAgo: 22,
            payer: alex,
            participants: [currentUser, alex, sarah],
            splitMethod: "Equal"
        )

        // MARK: 23 days ago
        createTransaction(
            context: context,
            title: "Internet Bill - Xfinity",
            amount: 89.99,
            daysAgo: 23,
            payer: sarah,
            participants: [currentUser, sarah],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 24 days ago
        createTransaction(
            context: context,
            title: "Game Night Snacks",
            amount: 45.00,
            daysAgo: 24,
            payer: currentUser,
            participants: [currentUser, mike, emma],
            splitMethod: "Equal",
            group: workLunch
        )

        // MARK: 25 days ago
        createTransaction(
            context: context,
            title: "Car Wash Subscription",
            amount: 29.99,
            daysAgo: 25,
            payer: currentUser,
            participants: [currentUser],
            splitMethod: "Equal"
        )

        // MARK: 26 days ago
        createTransaction(
            context: context,
            title: "IMAX Movie - Avengers",
            amount: 64.00,
            daysAgo: 26,
            payer: emma,
            participants: [currentUser, emma, mike, nick],
            splitMethod: "Equal",
            group: workLunch
        )

        // MARK: 28 days ago
        createTransaction(
            context: context,
            title: "Brunch at Cafe Milano",
            amount: 98.50,
            daysAgo: 28,
            payer: currentUser,
            participants: [currentUser, sarah, alex],
            splitMethod: "Equal",
            group: roommates
        )

        // MARK: 30 days ago
        createTransaction(
            context: context,
            title: "Road Trip Gas - Day 1",
            amount: 120.00,
            daysAgo: 30,
            payer: david,
            participants: [currentUser, alex, nick, sarah, david, emma],
            splitMethod: "Equal",
            group: roadTrip
        )
    }

    private static func createTransaction(
        context: NSManagedObjectContext,
        title: String,
        amount: Double,
        daysAgo: Int,
        hoursAgo: Int = 0,
        payer: Person,
        participants: [Person],
        splitMethod: String,
        group: UserGroup? = nil
    ) {
        let transaction = FinancialTransaction(context: context)
        transaction.id = UUID()
        transaction.title = title
        transaction.amount = amount
        transaction.date = date(daysAgo: daysAgo, hoursAgo: hoursAgo)
        transaction.payer = payer
        transaction.splitMethod = splitMethod
        transaction.group = group

        // Create splits
        let shareAmount = amount / Double(participants.count)
        for participant in participants {
            let split = TransactionSplit(context: context)
            split.amount = shareAmount
            split.rawAmount = shareAmount
            split.owedBy = participant
            split.transaction = transaction
        }
    }

    // MARK: - Settlements Creation

    private static func createSettlements(
        context: NSManagedObjectContext,
        people: [String: Person],
        currentUser: Person
    ) {
        let alex = people["Alex Johnson"]!
        let sarah = people["Sarah Chen"]!
        let mike = people["Mike Williams"]!
        let nick = people["Nick Thompson"]!
        let emma = people["Emma Davis"]!

        // Alex paid You back for concert tickets
        createSettlement(
            context: context,
            from: alex,
            to: currentUser,
            amount: 125.00,
            daysAgo: 2,
            note: "Concert tickets - thanks!"
        )

        // You paid Sarah for electricity
        createSettlement(
            context: context,
            from: currentUser,
            to: sarah,
            amount: 90.00,
            daysAgo: 5,
            note: "Electricity bill share"
        )

        // Mike paid You back for lunch
        createSettlement(
            context: context,
            from: mike,
            to: currentUser,
            amount: 21.25,
            daysAgo: 7,
            note: "Lunch reimbursement"
        )

        // You paid Nick for road trip gas
        createSettlement(
            context: context,
            from: currentUser,
            to: nick,
            amount: 150.00,
            daysAgo: 14,
            note: "Road trip gas"
        )

        // Emma paid You back for movie tickets
        createSettlement(
            context: context,
            from: emma,
            to: currentUser,
            amount: 16.00,
            daysAgo: 21,
            note: "Movie tickets"
        )
    }

    private static func createSettlement(
        context: NSManagedObjectContext,
        from: Person,
        to: Person,
        amount: Double,
        daysAgo: Int,
        note: String,
        isFullSettlement: Bool = false
    ) {
        let settlement = Settlement(context: context)
        settlement.id = UUID()
        settlement.amount = amount
        settlement.date = date(daysAgo: daysAgo)
        settlement.note = note
        settlement.isFullSettlement = isFullSettlement
        settlement.fromPerson = from
        settlement.toPerson = to
    }

    // MARK: - Reminders Creation

    private static func createReminders(
        context: NSManagedObjectContext,
        people: [String: Person],
        currentUser: Person
    ) {
        let alex = people["Alex Johnson"]!
        let nick = people["Nick Thompson"]!
        let sarah = people["Sarah Chen"]!

        // Reminder to Alex
        createReminder(
            context: context,
            to: alex,
            amount: 85.50,
            message: "Hey! Don't forget about the Airbnb split",
            daysAgo: 1,
            isRead: false
        )

        // Reminder to Nick
        createReminder(
            context: context,
            to: nick,
            amount: 150.00,
            message: "Ski rental money when you get a chance",
            daysAgo: 3,
            isRead: true
        )

        // Reminder to Sarah
        createReminder(
            context: context,
            to: sarah,
            amount: 44.99,
            message: "Netflix + Internet share for this month",
            daysAgo: 5,
            isRead: false
        )
    }

    private static func createReminder(
        context: NSManagedObjectContext,
        to: Person,
        amount: Double,
        message: String,
        daysAgo: Int,
        isRead: Bool
    ) {
        let reminder = Reminder(context: context)
        reminder.id = UUID()
        reminder.toPerson = to
        reminder.amount = amount
        reminder.message = message
        reminder.createdDate = date(daysAgo: daysAgo)
        reminder.isRead = isRead
        reminder.isCleared = false
    }

    // MARK: - Chat Messages Creation

    private static func createChatMessages(
        context: NSManagedObjectContext,
        people: [String: Person],
        groups: [String: UserGroup],
        currentUser: Person
    ) {
        let alex = people["Alex Johnson"]!
        let sarah = people["Sarah Chen"]!
        let mike = people["Mike Williams"]!

        // Conversation with Alex
        createChatMessage(
            context: context,
            content: "Hey, did you get my Venmo request?",
            withPerson: alex,
            isFromUser: false,
            daysAgo: 1,
            hoursAgo: 5
        )

        createChatMessage(
            context: context,
            content: "Yes! Will send it tonight",
            withPerson: alex,
            isFromUser: true,
            daysAgo: 1,
            hoursAgo: 4
        )

        createChatMessage(
            context: context,
            content: "Thanks!",
            withPerson: alex,
            isFromUser: false,
            daysAgo: 1,
            hoursAgo: 3
        )

        // Conversation with Sarah
        createChatMessage(
            context: context,
            content: "Rent's due on the 1st, don't forget your share",
            withPerson: sarah,
            isFromUser: false,
            daysAgo: 3,
            hoursAgo: 10
        )

        createChatMessage(
            context: context,
            content: "Got it, will transfer tomorrow",
            withPerson: sarah,
            isFromUser: true,
            daysAgo: 3,
            hoursAgo: 8
        )

        // Conversation with Mike
        createChatMessage(
            context: context,
            content: "Lunch today?",
            withPerson: mike,
            isFromUser: false,
            daysAgo: 0,
            hoursAgo: 6
        )

        createChatMessage(
            context: context,
            content: "Sure! Same place?",
            withPerson: mike,
            isFromUser: true,
            daysAgo: 0,
            hoursAgo: 5
        )

        createChatMessage(
            context: context,
            content: "Yeah, meet you at noon",
            withPerson: mike,
            isFromUser: false,
            daysAgo: 0,
            hoursAgo: 4
        )

        // Group conversation - Roommates
        if let roommates = groups["Roommates"] {
            createGroupChatMessage(
                context: context,
                content: "Who's taking out the trash this week?",
                withGroup: roommates,
                isFromUser: false,
                daysAgo: 2,
                hoursAgo: 12
            )

            createGroupChatMessage(
                context: context,
                content: "I did it last week, it's Alex's turn",
                withGroup: roommates,
                isFromUser: true,
                daysAgo: 2,
                hoursAgo: 10
            )
        }

        // Group conversation - Work Lunch Crew
        if let workLunch = groups["Work Lunch Crew"] {
            createGroupChatMessage(
                context: context,
                content: "Anyone up for Thai food tomorrow?",
                withGroup: workLunch,
                isFromUser: false,
                daysAgo: 1,
                hoursAgo: 20
            )

            createGroupChatMessage(
                context: context,
                content: "I'm in!",
                withGroup: workLunch,
                isFromUser: true,
                daysAgo: 1,
                hoursAgo: 18
            )
        }
    }

    private static func createChatMessage(
        context: NSManagedObjectContext,
        content: String,
        withPerson: Person,
        isFromUser: Bool,
        daysAgo: Int,
        hoursAgo: Int
    ) {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.withPerson = withPerson
        message.isFromUser = isFromUser
        message.timestamp = date(daysAgo: daysAgo, hoursAgo: hoursAgo)
    }

    private static func createGroupChatMessage(
        context: NSManagedObjectContext,
        content: String,
        withGroup: UserGroup,
        isFromUser: Bool,
        daysAgo: Int,
        hoursAgo: Int
    ) {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.withGroup = withGroup
        message.isFromUser = isFromUser
        message.timestamp = date(daysAgo: daysAgo, hoursAgo: hoursAgo)
    }

    // MARK: - Subscriptions Creation

    private static func createSubscriptions(
        context: NSManagedObjectContext,
        people: [String: Person],
        currentUser: Person
    ) {
        let sarah = people["Sarah Chen"]!
        let alex = people["Alex Johnson"]!

        // Personal subscriptions
        createSubscription(
            context: context,
            name: "Spotify Premium",
            amount: 10.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 45),
            isShared: false,
            subscribers: [currentUser]
        )

        createSubscription(
            context: context,
            name: "iCloud Storage",
            amount: 2.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 60),
            isShared: false,
            subscribers: [currentUser]
        )

        createSubscription(
            context: context,
            name: "Gym Membership",
            amount: 49.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 30),
            isShared: false,
            subscribers: [currentUser]
        )

        // Shared subscriptions
        createSubscription(
            context: context,
            name: "Netflix",
            amount: 22.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 90),
            isShared: true,
            subscribers: [currentUser, sarah, alex]
        )

        createSubscription(
            context: context,
            name: "Disney+",
            amount: 13.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 75),
            isShared: true,
            subscribers: [currentUser, sarah]
        )

        createSubscription(
            context: context,
            name: "HBO Max",
            amount: 15.99,
            cycle: "Monthly",
            startDate: date(daysAgo: 50),
            isShared: true,
            subscribers: [currentUser, alex]
        )
    }

    private static func createSubscription(
        context: NSManagedObjectContext,
        name: String,
        amount: Double,
        cycle: String,
        startDate: Date,
        isShared: Bool,
        subscribers: [Person]
    ) {
        let subscription = Subscription(context: context)
        subscription.id = UUID()
        subscription.name = name
        subscription.amount = amount
        subscription.cycle = cycle
        subscription.startDate = startDate
        subscription.isShared = isShared

        for subscriber in subscribers {
            subscription.addToSubscribers(subscriber)
        }
    }
}
