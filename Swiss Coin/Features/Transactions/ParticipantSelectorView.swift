import CoreData
import SwiftUI

struct ParticipantSelectorView: View {
    @Binding var selectedParticipants: Set<Person>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<UserGroup>

    @State private var pickerMode = 0

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingImportContacts = false

    var body: some View {
        VStack {
            Picker("Mode", selection: $pickerMode) {
                Text("People").tag(0)
                Text("Groups").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            List {
                if pickerMode == 0 {
                    ForEach(people) { person in
                        Button(action: {
                            toggle(person)
                        }) {
                            HStack {
                                Text(person.name ?? "Unknown")
                                Spacer()
                                if selectedParticipants.contains(person) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    ForEach(groups) { group in
                        Button(action: {
                            // When tapping a group, toggle all its members
                            toggleGroup(group)
                        }) {
                            HStack {
                                Text(group.name ?? "Unknown")
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }
            }

            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationTitle("Select Participants")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingImportContacts = true }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingImportContacts) {
            ImportContactsView { newPeople in
                for person in newPeople {
                    selectedParticipants.insert(person)
                }
            }
            .environment(\.managedObjectContext, viewContext)
        }
    }

    private func toggle(_ person: Person) {
        if selectedParticipants.contains(person) {
            selectedParticipants.remove(person)
        } else {
            selectedParticipants.insert(person)
        }
    }

    private func toggleGroup(_ group: UserGroup) {
        guard let members = group.members as? Set<Person> else { return }
        // Logic: Add any not currently selected
        for member in members {
            selectedParticipants.insert(member)
        }
    }
}
