import CoreData
import SwiftUI

struct PeopleView: View {
    @State private var selectedSegment = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNewMessage = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ActionHeaderButton(
                        title: "People",
                        icon: "person.2.fill",
                        color: selectedSegment == 0 ? .green : .primary
                    ) {
                        selectedSegment = 0
                    }

                    ActionHeaderButton(
                        title: "Groups",
                        icon: "person.3.fill",
                        color: selectedSegment == 1 ? .green : .primary
                    ) {
                        selectedSegment = 1
                    }
                }
                .padding(.horizontal)
                .padding(.top)
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
                NavigationLink(destination: PersonConversationView(person: person)) {
                    PersonListRowView(person: person)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(uiColor: .secondarySystemBackground))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

struct PersonListRowView: View {
    @ObservedObject var person: Person

    private var balance: Double {
        person.calculateBalance()
    }

    private var balanceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: abs(balance))) ?? "$0.00"

        if balance > 0.01 {
            return "owes you \(formatted)"
        } else if balance < -0.01 {
            return "you owe \(formatted)"
        } else {
            return "settled up"
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return .green
        } else if balance < -0.01 {
            return .red
        } else {
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: person.colorHex ?? "#34C759").opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(person.initials)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: person.colorHex ?? "#34C759"))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(person.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(balanceText)
                    .font(.subheadline)
                    .foregroundColor(balanceColor)
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text(NumberFormatter.localizedString(from: NSNumber(value: abs(balance)), number: .currency))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
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

                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.name ?? "Unknown Group")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(group.members?.count ?? 0) members")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color(uiColor: .secondarySystemBackground))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
