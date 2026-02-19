//
//  ContactDiscoveryService.swift
//  Swiss Coin
//
//  Hash-based phone contact matching. Discovers which of the user's
//  contacts are also registered on Swiss Coin via SHA-256 phone hashes.
//

import Combine
import CoreData
import CryptoKit
import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.swisscoin", category: "contact-discovery")

@MainActor
final class ContactDiscoveryService: ObservableObject {
    static let shared = ContactDiscoveryService()

    @Published private(set) var isDiscovering = false
    @Published private(set) var lastDiscoveryDate: Date?

    private init() {
        lastDiscoveryDate = UserDefaults.standard.object(forKey: "lastContactDiscoveryDate") as? Date
    }

    // MARK: - Phone Hashing

    /// Normalize phone to E.164 and compute SHA-256 hex hash
    static func hashPhoneNumber(_ phone: String) -> String {
        // Ensure E.164 format (strip spaces, dashes, parens)
        let normalized = phone.components(separatedBy: CharacterSet.decimalDigits.inverted.subtracting(CharacterSet(charactersIn: "+"))).joined()
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Discovery

    /// Discover which contacts are on Swiss Coin
    func discoverContacts(context: NSManagedObjectContext) async {
        guard !isDiscovering else { return }
        guard AuthManager.shared.currentUserId != nil else { return }

        isDiscovering = true
        defer { isDiscovering = false }

        do {
            // 1. Fetch all Person entities with phone numbers from CoreData
            let personsData: [(objectID: NSManagedObjectID, phone: String)] = await context.perform {
                let request: NSFetchRequest<Person> = Person.fetchRequest()
                request.predicate = NSPredicate(format: "phoneNumber != nil AND phoneNumber != ''")
                let persons = (try? context.fetch(request)) ?? []
                return persons
                    .filter { !CurrentUser.isCurrentUser($0.id) }
                    .compactMap { person in
                        guard let phone = person.phoneNumber else { return nil }
                        return (objectID: person.objectID, phone: phone)
                    }
            }

            guard !personsData.isEmpty else {
                logger.info("No contacts with phone numbers to discover")
                return
            }

            // 2. Hash all phones and build lookup map
            var hashToObjectID: [String: NSManagedObjectID] = [:]
            var hashes: [String] = []
            for data in personsData {
                let hash = Self.hashPhoneNumber(data.phone)
                hashToObjectID[hash] = data.objectID
                hashes.append(hash)
            }

            // 3. Call discover-contacts edge function
            let response: DiscoverContactsResponse = try await SupabaseConfig.client.functions.invoke(
                "discover-contacts",
                options: .init(body: ["hashed_phones": hashes])
            )

            // 4. Update matched Persons in CoreData
            let matches = response.matches
            let matchedHashes = Set(matches.map(\.phoneHash))

            await context.perform {
                // Update matches
                for match in matches {
                    guard let objectID = hashToObjectID[match.phoneHash],
                          let person = try? context.existingObject(with: objectID) as? Person
                    else { continue }

                    person.isOnSwissCoin = true
                    if let profileId = UUID(uuidString: match.profileId) {
                        person.linkedProfileId = profileId
                    }
                }

                // Reset unmatched (handle deregistration)
                for (hash, objectID) in hashToObjectID {
                    if !matchedHashes.contains(hash) {
                        if let person = try? context.existingObject(with: objectID) as? Person {
                            person.isOnSwissCoin = false
                            person.linkedProfileId = nil
                        }
                    }
                }

                try? context.save()
            }

            // 5. Update last discovery date
            let now = Date()
            lastDiscoveryDate = now
            UserDefaults.standard.set(now, forKey: "lastContactDiscoveryDate")

            logger.info("Contact discovery completed: \(matches.count) matches found")
        } catch {
            logger.error("Contact discovery failed: \(error.localizedDescription)")
        }
    }

    /// Check if discovery should run (throttled to once per hour)
    var shouldRunDiscovery: Bool {
        guard let last = lastDiscoveryDate else { return true }
        return Date().timeIntervalSince(last) > 3600 // 1 hour
    }
}

// MARK: - Response Types

private struct DiscoverContactsResponse: Decodable {
    let matches: [ContactMatch]
}

private struct ContactMatch: Decodable {
    let phoneHash: String
    let profileId: String
    let displayName: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case phoneHash = "phone_hash"
        case profileId = "profile_id"
        case displayName = "display_name"
        case photoUrl = "photo_url"
    }
}
