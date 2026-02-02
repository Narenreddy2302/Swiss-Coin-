import SwiftUI

struct MainTabView: View {
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

            SubscriptionView()
                .tabItem {
                    Label("Subscriptions", systemImage: "creditcard.fill")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .tint(AppColors.accent)
    }
}
