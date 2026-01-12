import Contacts
import CoreData
import SwiftUI

struct AddGroupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @StateObject private var contactsManager = ContactsManager()

    @State private var groupName: String = ""
    @State private var searchText = ""
    @State private var selectedContacts: Set<ContactsManager.PhoneContact> = []

    var filteredContacts: [ContactsManager.PhoneContact] {
        if searchText.isEmpty {
            return contactsManager.contacts
        } else {
            return contactsManager.contacts.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack {
            // Group Name Input
            VStack(alignment: .leading) {
                Text("Group Name")
                    .font(.headline)
                    .padding(.leading)

                TextField("Enter group name", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }
            .padding(.top)

            // Selected Members Preview
            if !selectedContacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(selectedContacts), id: \.id) { contact in
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    Text(contact.initials)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                Text(contact.firstName)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                selectedContacts.remove(contact)
                            }
                        }
                    }
                    .padding()
                }
            }

            // Contact List
            List {
                if contactsManager.authorizationStatus == .authorized {
                    Section(header: Text("Add Members")) {
                        ForEach(filteredContacts) { contact in
                            Button(action: {
                                toggleSelection(for: contact)
                            }) {
                                HStack {
                                    // Avatar Logic
                                    if let data = contact.thumbnailImageData,
                                        let uiImage = UIImage(data: data)
                                    {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                            Text(contact.initials)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 40, height: 40)
                                    }

                                    Text(contact.fullName)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if selectedContacts.contains(contact) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Permission Request Button
                    Button("Load Contacts") {
                        Task { await contactsManager.requestAccess() }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText)
        }
        .navigationTitle("New Group")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createGroup()
                }
                .disabled(groupName.isEmpty || selectedContacts.isEmpty)
            }
        }
        .task {
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    private func toggleSelection(for contact: ContactsManager.PhoneContact) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }

    private func createGroup() {
        let newGroup = UserGroup(context: viewContext)
        newGroup.id = UUID()
        newGroup.name = groupName
        newGroup.createdDate = Date()
        newGroup.colorHex = "#" + String(Int.random(in: 0...0xFFFFFF), radix: 16)

        for contact in selectedContacts {
            // Find or Create Person Logic
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", contact.fullName)
            fetchRequest.fetchLimit = 1

            do {
                let results = try viewContext.fetch(fetchRequest)
                let person: Person
                if let existing = results.first {
                    person = existing
                } else {
                    person = Person(context: viewContext)
                    person.id = UUID()
                    person.name = contact.fullName
                    person.phoneNumber = contact.phoneNumbers.first
                    person.colorHex = "#" + String(Int.random(in: 0...0xFFFFFF), radix: 16)
                }
                newGroup.addToMembers(person)
            } catch {
                print("Error finding/creating person: \(error)")
            }
        }

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving group: \(error)")
        }
    }
}
