import Combine
import Contacts
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
    private static let cacheValidityDuration: TimeInterval = 60 // Cache valid for 60 seconds
    
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
}
