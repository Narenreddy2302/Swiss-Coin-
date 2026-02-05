import CoreData
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch unread reminders for People badge (limited for performance)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.createdDate, ascending: false)]
        request.predicate = NSPredicate(format: "isRead == NO")
        request.fetchLimit = 99  // Badge max
        return request
    }(), animation: .default)
    private var unreadReminders: FetchedResults<Reminder>

    // Fetch unread chat messages (non-user messages) for People badge (limited for performance)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        request.predicate = NSPredicate(format: "isFromUser == NO")
        request.fetchLimit = 99
        return request
    }(), animation: .default)
    private var incomingMessages: FetchedResults<ChatMessage>

    // Fetch active subscriptions for due-soon badge (limited for performance)
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Subscription.nextBillingDate, ascending: true)]
        let threeDaysFromNow: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "isActive == YES AND nextBillingDate <= %@", 
            threeDaysFromNow as NSDate)
        request.fetchLimit = 99
        return request
    }(), animation: .default)
    private var activeSubscriptions: FetchedResults<Subscription>

    /// Badge count for People tab: unread reminders count
    private var peopleBadge: Int {
        unreadReminders.count
    }

    /// Badge count for Subscriptions tab: subscriptions due within 3 days
    /// Now computed directly from fetch results since predicate already filters
    private var subscriptionsBadge: Int {
        activeSubscriptions.count
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
        .tint(AppColors.textPrimary)
    }
}
