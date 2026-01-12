import CoreData
import SwiftUI

struct PeopleView: View {
    @State private var selectedSegment = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNewMessage = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("People").tag(0)
                    Text("Groups").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))

                if selectedSegment == 0 {
                    PersonListView()
                } else {
                    GroupListView()
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectedSegment == 0 {
                            Button(action: { showingNewMessage = true }) {
                                Image(systemName: "square.and.pencil")
                            }
                            NavigationLink(destination: AddPersonView()) {
                                Image(systemName: "plus")
                            }
                        } else {
                            NavigationLink(destination: AddGroupView()) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                NewTransactionContactView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

struct PersonListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        predicate: NSPredicate(format: "toTransactions.@count > 0 OR owedSplits.@count > 0"),
        animation: .default)
    private var people: FetchedResults<Person>

    var body: some View {
        List {
            ForEach(people) { person in
                NavigationLink(destination: PersonDetailView(person: person)) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.green.opacity(0.2))  // Brand color
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(person.name?.prefix(1).uppercased() ?? "?")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name ?? "Unknown")
                                .font(.headline)
                                .foregroundColor(.primary)

                            // Subtitle simulating "Latest Episode" or similar context
                            Text("See transactions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

struct GroupListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<UserGroup>

    var body: some View {
        List {
            ForEach(groups) { group in
                NavigationLink(destination: GroupDetailView(group: group)) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.3.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name ?? "Unknown Group")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(group.members?.count ?? 0) members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
