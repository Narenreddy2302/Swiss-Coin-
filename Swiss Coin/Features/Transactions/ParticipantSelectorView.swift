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
                            HapticManager.selectionChanged()
                            toggle(person)
                        }) {
                            HStack {
                                // Show "Me" for current user, otherwise show name
                                if CurrentUser.isCurrentUser(person.id) {
                                    Text("Me")
                                        .font(AppTypography.bodyBold())
                                        .foregroundColor(AppColors.textPrimary)
                                } else {
                                    Text(person.name ?? "Unknown")
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                Spacer()
                                if selectedParticipants.contains(person) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.positive)
                                        .font(.system(size: IconSize.md))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(groups) { group in
                        Button(action: {
                            HapticManager.tap()
                            toggleGroup(group)
                        }) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(AppColors.accent)
                                    .font(.system(size: IconSize.md))
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(group.name ?? "Unknown Group")
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                    let memberCount = (group.members as? Set<Person>)?.count ?? 0
                                    Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(AppColors.accent)
                                    .font(.system(size: IconSize.md))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary)
        }
        .background(AppColors.backgroundSecondary)
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
