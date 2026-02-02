import CoreData
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch unread reminders for People badge
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isRead == NO"),
        animation: .default)
    private var unreadReminders: FetchedResults<Reminder>

    // Fetch unread chat messages (non-user messages) for People badge
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isFromUser == NO"),
        animation: .default)
    private var incomingMessages: FetchedResults<ChatMessage>

    // Fetch active subscriptions for due-soon badge
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var activeSubscriptions: FetchedResults<Subscription>

    /// Badge count for People tab: unread reminders count
    private var peopleBadge: Int {
        unreadReminders.count
    }

    /// Badge count for Subscriptions tab: subscriptions due within 3 days
    private var subscriptionsBadge: Int {
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return activeSubscriptions.filter { sub in
            guard let nextDate = sub.nextBillingDate else { return false }
            return nextDate <= threeDaysFromNow
        }.count
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PeopleView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }
                .badge(peopleBadge > 0 ? peopleBadge : 0)

            SubscriptionView()
                .tabItem {
                    Label("Subscriptions", systemImage: "creditcard.fill")
                }
                .badge(subscriptionsBadge > 0 ? subscriptionsBadge : 0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .tint(AppColors.accent)
    }
}
