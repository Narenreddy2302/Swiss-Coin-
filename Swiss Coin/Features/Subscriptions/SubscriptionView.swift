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
                Picker("Type", selection: $filterSegment) {
                    Text("Personal").tag(0)
                    Text("Shared").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                List {
                    ForEach(filteredSubscriptions) { sub in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sub.name ?? "Unknown Subscription")
                                    .font(.headline)
                                Text(sub.cycle ?? "Monthly")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(
                                Formatters.currency.string(from: NSNumber(value: sub.amount))
                                    ?? "$0.00")
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .overlay(
                    SwiftUI.Group {
                        if filteredSubscriptions.isEmpty {
                            Text("No subscriptions found")
                                .foregroundColor(.secondary)
                        }
                    }
                )
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))
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
