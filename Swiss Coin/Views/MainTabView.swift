import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "play.circle.fill")
                }

            PeopleView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }

            SubscriptionView()
                .tabItem {
                    Label("Subscriptions", systemImage: "square.grid.2x2.fill")
                }

            TransactionHistoryView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .tint(.green) // Using app's brand color
    }
}
