import CoreData
import Foundation

struct MockDataGenerator {

    // MARK: - Transaction Categories for realistic data
    enum TransactionCategory: String, CaseIterable {
        case dining = "Dining"
        case entertainment = "Entertainment"
        case travel = "Travel"
        case utilities = "Utilities"
        case shopping = "Shopping"
        case subscriptions = "Subscriptions"
        case healthcare = "Healthcare"
        case education = "Education"
        case transportation = "Transportation"
        case personal = "Personal"
    }

    // MARK: - Main Seed Function
    static func seed(context: NSManagedObjectContext) {
        // Create people for the transactions
        let me = getPerson(name: "You", context: context)
        let alex = getPerson(name: "Alex", context: context)
        let nick = getPerson(name: "Nick", context: context)
        let sarah = getPerson(name: "Sarah", context: context)
        let mike = getPerson(name: "Mike", context: context)
        let emma = getPerson(name: "Emma", context: context)
        let david = getPerson(name: "David", context: context)

        // MARK: - Today's Transactions

        // 1. Morning Coffee Run - You treated Sarah
        // You paid $12.50 for 2 coffees, Sarah owes you $6.25
        createTransaction(
            context: context,
            title: "Morning Coffee Run",
            amount: 12.50,
            date: Date().addingTimeInterval(-3600), // 1 hour ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, sarah]
        )

        // 2. Team Lunch at Chipotle
        // Mike paid $85 for 5 people, you owe $17
        createTransaction(
            context: context,
            title: "Team Lunch at Chipotle",
            amount: 85.00,
            date: Date().addingTimeInterval(-7200), // 2 hours ago
            payer: mike,
            splitMethod: "Equal",
            participants: [me, mike, alex, sarah, nick]
        )

        // 3. Uber Pool to Office
        // Alex paid for the ride, split between 3 people
        createTransaction(
            context: context,
            title: "Uber Pool to Office",
            amount: 24.00,
            date: Date().addingTimeInterval(-28800), // 8 hours ago
            payer: alex,
            splitMethod: "Equal",
            participants: [me, alex, emma]
        )

        // MARK: - Yesterday's Transactions

        // 4. Grocery Shopping at Whole Foods
        // You paid $156.78, split 3 ways (roommates)
        createTransaction(
            context: context,
            title: "Grocery Shopping - Whole Foods",
            amount: 156.78,
            date: Date().addingTimeInterval(-86400), // 1 day ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, nick, sarah]
        )

        // 5. Netflix Monthly Subscription
        // You paid for shared subscription with 4 people
        createTransaction(
            context: context,
            title: "Netflix Subscription",
            amount: 22.99,
            date: Date().addingTimeInterval(-86400),
            payer: me,
            splitMethod: "Equal",
            participants: [me, alex, sarah, emma]
        )

        // 6. Dinner at Italian Restaurant
        // Sarah paid $220 for birthday dinner with 4 people
        createTransaction(
            context: context,
            title: "Birthday Dinner - Olive Garden",
            amount: 220.00,
            date: Date().addingTimeInterval(-86400 - 7200),
            payer: sarah,
            splitMethod: "Equal",
            participants: [me, sarah, nick, mike]
        )

        // MARK: - This Week's Transactions

        // 7. Concert Tickets - Weekend Event
        // You bought 3 tickets at $75 each = $225
        createTransaction(
            context: context,
            title: "Concert Tickets - Taylor Swift",
            amount: 225.00,
            date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, alex, emma]
        )

        // 8. Electricity Bill Split
        // You paid the utility bill, roommates owe you
        createTransaction(
            context: context,
            title: "Electricity Bill - January",
            amount: 180.00,
            date: Date().addingTimeInterval(-86400 * 2),
            payer: me,
            splitMethod: "Equal",
            participants: [me, nick, sarah]
        )

        // 9. Gym Membership - Joint Annual
        // Nick paid annual membership for him and you
        createTransaction(
            context: context,
            title: "Gym Annual Membership",
            amount: 600.00,
            date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            payer: nick,
            splitMethod: "Equal",
            participants: [me, nick]
        )

        // 10. Gas Station Fill-up
        // Road trip, David paid for gas
        createTransaction(
            context: context,
            title: "Gas Station - Road Trip",
            amount: 78.50,
            date: Date().addingTimeInterval(-86400 * 3),
            payer: david,
            splitMethod: "Equal",
            participants: [me, david, alex, mike]
        )

        // 11. Movie Night - IMAX
        // Emma paid for group movie
        createTransaction(
            context: context,
            title: "IMAX Movie - Avengers",
            amount: 96.00,
            date: Date().addingTimeInterval(-86400 * 4), // 4 days ago
            payer: emma,
            splitMethod: "Equal",
            participants: [me, emma, sarah, nick]
        )

        // 12. Spotify Family Plan
        // You manage the family plan for 6 people
        createTransaction(
            context: context,
            title: "Spotify Family Plan",
            amount: 16.99,
            date: Date().addingTimeInterval(-86400 * 5), // 5 days ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, alex, nick, sarah, mike, emma]
        )

        // MARK: - Last Week's Transactions

        // 13. Weekend Brunch
        // You paid for brunch with friends
        createTransaction(
            context: context,
            title: "Sunday Brunch - The Cheesecake Factory",
            amount: 145.00,
            date: Date().addingTimeInterval(-86400 * 6), // 6 days ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, sarah, emma]
        )

        // 14. Airbnb for Weekend Trip
        // Alex booked the Airbnb, split among 6 people
        createTransaction(
            context: context,
            title: "Airbnb - Lake Tahoe Weekend",
            amount: 850.00,
            date: Date().addingTimeInterval(-86400 * 7), // 1 week ago
            payer: alex,
            splitMethod: "Equal",
            participants: [me, alex, nick, sarah, mike, emma]
        )

        // 15. Internet Bill
        // Monthly internet split with roommates
        createTransaction(
            context: context,
            title: "Internet Bill - Xfinity",
            amount: 89.99,
            date: Date().addingTimeInterval(-86400 * 7),
            payer: me,
            splitMethod: "Equal",
            participants: [me, nick, sarah]
        )

        // MARK: - Two Weeks Ago

        // 16. Flight Tickets - Personal Expense
        // You bought your own flight ticket
        createTransaction(
            context: context,
            title: "Flight Ticket - NYC Trip",
            amount: 385.00,
            date: Date().addingTimeInterval(-86400 * 10), // 10 days ago
            payer: me,
            splitMethod: "Exact Amount",
            participants: [me]
        )

        // 17. Group Dinner at Sushi Place
        // Mike treated everyone at an expensive sushi restaurant
        createTransaction(
            context: context,
            title: "Sushi Dinner - Nobu",
            amount: 480.00,
            date: Date().addingTimeInterval(-86400 * 12), // 12 days ago
            payer: mike,
            splitMethod: "Equal",
            participants: [me, mike, alex, sarah, david]
        )

        // 18. Amazon Prime Annual
        // You share Prime with family
        createTransaction(
            context: context,
            title: "Amazon Prime Annual",
            amount: 139.00,
            date: Date().addingTimeInterval(-86400 * 14), // 2 weeks ago
            payer: me,
            splitMethod: "Equal",
            participants: [me, alex]
        )

        // MARK: - Earlier This Month

        // 19. Doctor Visit Co-pay
        // Personal medical expense
        createTransaction(
            context: context,
            title: "Doctor Visit Co-pay",
            amount: 50.00,
            date: Date().addingTimeInterval(-86400 * 18), // 18 days ago
            payer: me,
            splitMethod: "Exact Amount",
            participants: [me]
        )

        // 20. Escape Room Experience
        // David organized team building activity
        createTransaction(
            context: context,
            title: "Escape Room - Team Building",
            amount: 180.00,
            date: Date().addingTimeInterval(-86400 * 20), // 20 days ago
            payer: david,
            splitMethod: "Equal",
            participants: [me, david, alex, nick, mike, emma]
        )

        // 21. Wine Tasting Tour
        // Emma organized Napa Valley trip
        createTransaction(
            context: context,
            title: "Wine Tasting - Napa Valley",
            amount: 320.00,
            date: Date().addingTimeInterval(-86400 * 22), // 22 days ago
            payer: emma,
            splitMethod: "Equal",
            participants: [me, emma, sarah, alex]
        )

        // 22. Pet Supplies (Personal)
        createTransaction(
            context: context,
            title: "Pet Supplies - PetSmart",
            amount: 78.45,
            date: Date().addingTimeInterval(-86400 * 25), // 25 days ago
            payer: me,
            splitMethod: "Exact Amount",
            participants: [me]
        )

        // 23. Ski Trip Equipment Rental
        // Nick rented ski gear for the group
        createTransaction(
            context: context,
            title: "Ski Equipment Rental",
            amount: 450.00,
            date: Date().addingTimeInterval(-86400 * 28), // 28 days ago
            payer: nick,
            splitMethod: "Equal",
            participants: [me, nick, alex, sarah, mike]
        )

        // 24. Game Night Snacks
        // Sarah hosted game night, bought all snacks
        createTransaction(
            context: context,
            title: "Game Night Snacks & Drinks",
            amount: 65.00,
            date: Date().addingTimeInterval(-86400 * 30), // 1 month ago
            payer: sarah,
            splitMethod: "Equal",
            participants: [me, sarah, nick, alex, emma]
        )

        // 25. Car Wash Subscription
        // You and Mike share unlimited car wash
        createTransaction(
            context: context,
            title: "Car Wash Subscription",
            amount: 29.99,
            date: Date().addingTimeInterval(-86400 * 30),
            payer: me,
            splitMethod: "Equal",
            participants: [me, mike]
        )

        // Save all transactions
        do {
            try context.save()
            print("✅ Successfully seeded \(25) mock transactions")
        } catch {
            print("❌ Error saving mock data: \(error)")
        }
    }

    // MARK: - Helper Functions

    private static func getPerson(name: String, context: NSManagedObjectContext) -> Person {
        let request = Person.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let newPerson = Person(context: context)
        newPerson.id = UUID()
        newPerson.name = name
        return newPerson
    }

    private static func createTransaction(
        context: NSManagedObjectContext,
        title: String,
        amount: Double,
        date: Date,
        payer: Person,
        splitMethod: String,
        participants: [Person]
    ) {
        // Prevent duplicate transactions
        let fetchRequest = FinancialTransaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@ AND amount == %lf", title, amount)

        if (try? context.count(for: fetchRequest)) ?? 0 > 0 {
            return
        }

        let transaction = FinancialTransaction(context: context)
        transaction.id = UUID()
        transaction.title = title
        transaction.amount = amount
        transaction.date = date
        transaction.payer = payer
        transaction.splitMethod = splitMethod

        // Create splits based on participants
        let participantCount = Double(participants.count)
        let sharePerPerson = amount / participantCount

        for participant in participants {
            let split = TransactionSplit(context: context)
            split.transaction = transaction
            split.owedBy = participant

            // Calculate split amount
            if participants.count == 1 {
                // Personal expense - full amount
                split.amount = amount
            } else {
                // Equal split among participants
                split.amount = sharePerPerson
            }
        }
    }

    // MARK: - Clear All Data (for testing purposes)
    static func clearAllData(context: NSManagedObjectContext) {
        let entities = ["FinancialTransaction", "TransactionSplit", "Person"]

        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                print("Error clearing \(entity): \(error)")
            }
        }

        do {
            try context.save()
            print("✅ All data cleared successfully")
        } catch {
            print("❌ Error saving after clear: \(error)")
        }
    }

    // MARK: - Reseed Data (clear and recreate)
    static func reseed(context: NSManagedObjectContext) {
        clearAllData(context: context)
        seed(context: context)
    }
}
