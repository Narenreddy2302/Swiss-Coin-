import Contacts
import CoreData
import SwiftUI

struct ImportContactsView: View {
    @StateObject private var contactsManager = ContactsManager()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedContacts: Set<ContactsManager.PhoneContact> = []
    @State private var searchText = ""

    var onImport: (([Person]) -> Void)?

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
        NavigationView {
            VStack {
                if contactsManager.authorizationStatus == .authorized {
                    List {
                        ForEach(filteredContacts) { contact in
                            Button(action: {
                                toggleSelection(contact)
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
                                                .foregroundColor(.primary)
                                        }
                                        .frame(width: 40, height: 40)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(contact.fullName)
                                            .font(.headline)
                                        if let phone = contact.phoneNumbers.first {
                                            Text(phone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

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
                            .foregroundColor(.primary)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText)
                } else if contactsManager.authorizationStatus == .denied {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Access Denied")
                            .font(.title2)
                        Text("Please enable contact access in Settings to import people.")
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
                        Text("Import Contacts")
                            .font(.title2)
                        Text("Connect your address book to easily split bills with friends.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Import Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        toggleSelectAll()
                    }) {
                        Text(areAllSelected ? "Deselect All" : "Select All")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selectedContacts.count))") {
                        importContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
        }
        .task {
            // Re-check status on appear in case user came back from settings
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    // Check if all CURRENTLY filtered contacts are selected
    var areAllSelected: Bool {
        guard !filteredContacts.isEmpty else { return false }
        // We check if the set of filtered contacts is a subset of selectedContacts
        return filteredContacts.allSatisfy { selectedContacts.contains($0) }
    }

    private func toggleSelectAll() {
        if areAllSelected {
            // Deselect all visible
            for contact in filteredContacts {
                selectedContacts.remove(contact)
            }
        } else {
            // Select all visible
            for contact in filteredContacts {
                selectedContacts.insert(contact)
            }
        }
    }

    private func toggleSelection(_ contact: ContactsManager.PhoneContact) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }

    private func importContacts() {
        var newPeople: [Person] = []

        for contact in selectedContacts {
            let newPerson = Person(context: viewContext)
            newPerson.id = UUID()
            newPerson.name = contact.fullName
            newPerson.phoneNumber = contact.phoneNumbers.first

            // Assign random color
            newPerson.colorHex = "#" + String(Int.random(in: 0...0xFFFFFF), radix: 16)

            newPeople.append(newPerson)
        }

        do {
            try viewContext.save()
            onImport?(newPeople)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving imported contacts: \(error)")
        }
    }
}
