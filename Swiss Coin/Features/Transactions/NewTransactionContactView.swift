import Contacts
import CoreData
import SwiftUI

struct NewTransactionContactView: View {
    @StateObject private var contactsManager = ContactsManager()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var selectedPersonForTransaction: Person?
    @State private var navigateToAddTransaction = false

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
        NavigationStack {
            VStack {
                if contactsManager.authorizationStatus == .authorized {
                    List {
                        // WhatsApp Style Header Rows
                        Section {
                            NavigationLink(destination: AddGroupView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 40, height: 40)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("New Group")
                                        .foregroundColor(.blue)
                                        .font(.headline)
                                }
                            }

                            NavigationLink(destination: AddPersonView()) {
                                HStack {
                                    Image(systemName: "person.fill.badge.plus")
                                        .foregroundColor(.blue)
                                        .frame(width: 40, height: 40)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("New Contact")
                                        .foregroundColor(.blue)
                                        .font(.headline)
                                }
                            }
                        }

                        // Contacts List
                        Section(header: Text("Contacts on Swiff")) {
                            ForEach(filteredContacts) { contact in
                                Button(action: {
                                    selectContact(contact)
                                }) {
                                    HStack {
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

                                        VStack(alignment: .leading) {
                                            Text(contact.fullName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if let phone = contact.phoneNumbers.first {
                                                Text(phone)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)  // WhatsApp uses plain list style for contacts
                    .scrollContentBackground(.hidden)
                    .searchable(
                        text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                } else if contactsManager.authorizationStatus == .denied {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Access Denied")
                            .font(.title2)
                        Text("Please enable contact access in Settings.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("Load Contacts")
                            .font(.title2)
                        Button("Continue") {
                            Task {
                                await contactsManager.requestAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationDestination(isPresented: $navigateToAddTransaction) {
                if let person = selectedPersonForTransaction {
                    PersonDetailView(person: person)
                }
            }
        }
        .task {
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    private func selectContact(_ contact: ContactsManager.PhoneContact) {
        // 1. Check if Person exists
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        // Simple check by name for now, ideally strictly by phone or ID if we stored it
        fetchRequest.predicate = NSPredicate(format: "name == %@", contact.fullName)
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existingPerson = results.first {
                self.selectedPersonForTransaction = existingPerson
            } else {
                // 2. Create new Person
                let newPerson = Person(context: viewContext)
                newPerson.id = UUID()
                newPerson.name = contact.fullName
                newPerson.phoneNumber = contact.phoneNumbers.first
                newPerson.colorHex = "#" + String(Int.random(in: 0...0xFFFFFF), radix: 16)

                try viewContext.save()
                self.selectedPersonForTransaction = newPerson
            }
            // 3. Navigate
            self.navigateToAddTransaction = true
        } catch {
            print("Error selecting contact: \(error)")
        }
    }
}
