import Combine
import Contacts
import SwiftUI

class ContactsManager: ObservableObject {
    @Published var contacts: [PhoneContact] = []
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined

    struct PhoneContact: Identifiable, Hashable {
        let id: String
        let firstName: String
        let lastName: String
        let phoneNumbers: [String]
        let emailAddresses: [String]
        let thumbnailImageData: Data?

        var fullName: String {
            [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        }

        var initials: String {
            let first = firstName.first.map(String.init) ?? ""
            let last = lastName.first.map(String.init) ?? ""
            return (first + last).uppercased()
        }
    }

    init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            if granted {
                await fetchContacts()
            }
            return granted
        } catch {
            print("Error requesting contact access: \(error)")
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
    }

    func fetchContacts() async {
        guard authorizationStatus == .authorized else { return }

        let store = CNContactStore()
        let keysToFetch =
            [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactThumbnailImageDataKey,
            ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .userDefault

        var fetchedContacts: [PhoneContact] = []

        do {
            try store.enumerateContacts(with: request) { (contact, stop) in
                let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                let emailAddresses = contact.emailAddresses.map { $0.value as String }

                let phoneContact = PhoneContact(
                    id: contact.identifier,
                    firstName: contact.givenName,
                    lastName: contact.familyName,
                    phoneNumbers: phoneNumbers,
                    emailAddresses: emailAddresses,
                    thumbnailImageData: contact.thumbnailImageData
                )
                fetchedContacts.append(phoneContact)
            }

            await MainActor.run {
                self.contacts = fetchedContacts
            }
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }
}
