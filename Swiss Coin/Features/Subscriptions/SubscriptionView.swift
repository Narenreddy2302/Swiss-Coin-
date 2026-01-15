import CoreData
import SwiftUI

struct SubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // 0 = Personal, 1 = Shared
    @State private var filterSegment = 0

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subscription.name, ascending: true)],
        animation: .default)
    private var subscriptions: FetchedResults<Subscription>

    var filteredSubscriptions: [Subscription] {
        subscriptions.filter { sub in
            if filterSegment == 0 {
                return !sub.isShared
            } else {
                return sub.isShared
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                filterHeader
                subscriptionList
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Add Subscription Action */  }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private var filterHeader: some View {
        HStack(spacing: 12) {
            ActionHeaderButton(
                title: "Personal",
                icon: "person.fill",
                color: filterSegment == 0 ? .green : .primary
            ) {
                filterSegment = 0
            }

            ActionHeaderButton(
                title: "Shared",
                icon: "person.2.fill",
                color: filterSegment == 1 ? .green : .primary
            ) {
                filterSegment = 1
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var subscriptionList: some View {
        List {
            ForEach(filteredSubscriptions) { sub in
                subscriptionRow(for: sub)
            }
            .onDelete(perform: deleteItems)
        }
        .overlay(emptyStateOverlay)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func subscriptionRow(for sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(sub.name ?? "Unknown Subscription")
                    .font(.headline)
                Text(sub.cycle ?? "Monthly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(CurrencyFormatter.format(sub.amount))
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if filteredSubscriptions.isEmpty {
            Text("No subscriptions found")
                .foregroundColor(.secondary)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredSubscriptions[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print(error)
            }
        }
    }
}
