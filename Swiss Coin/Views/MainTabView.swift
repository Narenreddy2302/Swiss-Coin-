import CoreData
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedTab = 0

    // Fetch all non-archived persons for badge calculation
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.sortDescriptors = []
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var allPersons: FetchedResults<Person>

    // Fetch all groups for badge calculation
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        request.sortDescriptors = []
        request.fetchBatchSize = 50
        return request
    }(), animation: .default)
    private var allGroups: FetchedResults<UserGroup>

    /// Badge count for People tab: contacts/groups with new activity since last viewed
    private var peopleBadge: Int {
        let currentUserId = CurrentUser.currentUserId
        let personCount = allPersons.filter { $0.id != currentUserId && $0.hasNewActivity }.count
        let groupCount = allGroups.filter { $0.hasNewActivity }.count
        return personCount + groupCount
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

            SubscriptionView()
                .tabItem {
                    Label("Subscriptions", systemImage: "creditcard.fill")
                }
                .tag(2)

            SearchView()
                .tabItem {
                    Label("Transactions", systemImage: "arrow.left.arrow.right")
                }
                .tag(3)
        }
        .tint(AppColors.accent)
    }
}
