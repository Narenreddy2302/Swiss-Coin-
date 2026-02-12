import CoreData
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedTab = 0

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

    /// Badge count for People tab: unread reminders count
    private var peopleBadge: Int {
        unreadReminders.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            PeopleView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }
                .badge(peopleBadge > 0 ? peopleBadge : 0)
                .tag(1)

            SearchView()
                .tabItem {
                    Label("Transactions", systemImage: "arrow.left.arrow.right")
                }
                .tag(2)
        }
        .tint(AppColors.accent)
    }
}
