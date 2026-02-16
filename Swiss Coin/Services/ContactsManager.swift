import Combine
import Contacts
import CoreData
import os
import SwiftUI

/// Manages phone contacts access and provides efficient caching
@MainActor
class ContactsManager: ObservableObject {
    @Published var contacts: [PhoneContact] = []
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    /// Static cache for contacts to avoid reloading on every view appearance
    private static var cachedContacts: [PhoneContact]?
    private static var lastFetchTime: Date?
    private static let cacheValidityDuration: TimeInterval = 300 // Cache valid for 5 minutes
    
    /// Represents a phone contact with all necessary details
    struct PhoneContact: Identifiable, Hashable, Sendable {
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
        
        // MARK: - Hashable
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: PhoneContact, rhs: PhoneContact) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        // Use cached contacts if available
        if let cached = ContactsManager.cachedContacts,
           ContactsManager.isCacheValid() {
            self.contacts = cached
        }
    }
    
    /// Checks if the cached contacts are still valid
    private static func isCacheValid() -> Bool {
        guard let lastFetch = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheValidityDuration
    }
    
    /// Requests access to contacts and fetches them if granted
    func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            self.authorizationStatus = granted ? .authorized : .denied
            if granted {
                await fetchContacts()
            }
            return granted
        } catch {
            AppLogger.contacts.error("Failed to request contact access: \(error.localizedDescription)")
            self.authorizationStatus = .denied
            return false
        }
    }
    
    /// Fetches contacts from the device with caching support
    /// Uses background thread for fetching and updates UI on main thread
    func fetchContacts() async {
        guard authorizationStatus == .authorized else { return }
        
        // Check if we have valid cached data
        if ContactsManager.cachedContacts != nil,
           ContactsManager.isCacheValid(),
           !self.contacts.isEmpty {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Fetch contacts on background thread for performance
        let fetchedContacts = await Task.detached(priority: .userInitiated) {
            await self.performContactFetch()
        }.value
        
        self.contacts = fetchedContacts
        ContactsManager.cachedContacts = fetchedContacts
        ContactsManager.lastFetchTime = Date()
    }
    
    /// Performs the actual contact fetch operation
    private nonisolated func performContactFetch() async -> [PhoneContact] {
        let store = CNContactStore()
        
        // Optimize keys to fetch - only get what we need
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .userDefault
        request.mutableObjects = false // Optimization: we don't need mutable objects
        
        var fetchedContacts: [PhoneContact] = []
        fetchedContacts.reserveCapacity(500) // Pre-allocate capacity for performance
        
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                // Skip contacts with no name and no phone
                guard !contact.givenName.isEmpty || 
                      !contact.familyName.isEmpty ||
                      !contact.phoneNumbers.isEmpty else {
                    return
                }
                
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
        } catch {
            // Log error on main actor since AppLogger is MainActor-isolated
            await MainActor.run {
                AppLogger.contacts.error("Failed to fetch contacts: \(error.localizedDescription)")
            }
        }
        
        return fetchedContacts
    }
    
    /// Clears the contact cache (useful for pull-to-refresh scenarios)
    static func clearCache() {
        cachedContacts = nil
        lastFetchTime = nil
    }
    
    /// Refreshes contacts by clearing cache and fetching fresh data
    func refreshContacts() async {
        ContactsManager.clearCache()
        await fetchContacts()
    }

    // MARK: - Person Creation Helpers

    /// Creates a Person entity from a PhoneContact
    static func createPerson(from contact: PhoneContact, in context: NSManagedObjectContext) -> Person {
        let newPerson = Person(context: context)
        newPerson.id = UUID()
        newPerson.name = contact.fullName
        newPerson.phoneNumber = contact.phoneNumbers.first
        newPerson.colorHex = String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
        newPerson.photoData = contact.thumbnailImageData
        return newPerson
    }

    /// Finds an existing Person entity matching a PhoneContact's phone number
    static func findExistingPerson(for contact: PhoneContact, in context: NSManagedObjectContext) -> Person? {
        for phone in contact.phoneNumbers {
            let normalized = phone.normalizedPhoneNumber()
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "phoneNumber == %@ OR phoneNumber == %@",
                normalized, phone
            )
            fetchRequest.fetchLimit = 1
            if let person = try? context.fetch(fetchRequest).first {
                return person
            }
        }
        return nil
    }

    /// Gets or creates a Person from a PhoneContact. Returns existing Person if phone matches.
    static func getOrCreatePerson(from contact: PhoneContact, in context: NSManagedObjectContext) -> Person {
        if let existing = findExistingPerson(for: contact, in: context) {
            return existing
        }
        return createPerson(from: contact, in: context)
    }

    /// Loads all existing Person phone numbers for filtering
    static func loadExistingPhoneNumbers(in context: NSManagedObjectContext) -> Set<String> {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber != nil AND phoneNumber != %@", "")

        do {
            let results = try context.fetch(fetchRequest)
            var phones: Set<String> = []
            for person in results {
                if let phone = person.phoneNumber {
                    phones.insert(phone.normalizedPhoneNumber())
                    phones.insert(phone)
                }
            }
            return phones
        } catch {
            return []
        }
    }

    /// Filters contacts to only those not already saved as Person entities
    func contactsNotInCoreData(existingPhoneNumbers: Set<String>) -> [PhoneContact] {
        contacts.filter { contact in
            // Keep contacts that have no phone numbers (can still be added by name)
            guard !contact.phoneNumbers.isEmpty else { return true }
            // Exclude if any phone number matches an existing Person
            return !contact.phoneNumbers.contains(where: { phone in
                let normalized = phone.normalizedPhoneNumber()
                return existingPhoneNumbers.contains(normalized) || existingPhoneNumbers.contains(phone)
            })
        }
    }

    /// Searches phone contacts by name/phone, excluding those already in CoreData.
    /// Combines filtering + search in a single pass for performance.
    func searchContacts(query: String, excludingPhoneNumbers: Set<String>) -> [ContactsManager.PhoneContact] {
        let search = query.lowercased()
        return contacts.filter { contact in
            // Must match search query
            guard contact.fullName.lowercased().contains(search) ||
                  contact.phoneNumbers.contains(where: { $0.contains(search) })
            else { return false }
            // Exclude contacts already in CoreData
            guard !contact.phoneNumbers.isEmpty else { return true }
            return !contact.phoneNumbers.contains(where: { phone in
                let normalized = phone.normalizedPhoneNumber()
                return excludingPhoneNumbers.contains(normalized) || excludingPhoneNumbers.contains(phone)
            })
        }
    }
}
