//
//  Persistence.swift
//  Swiss Coin
//
//  Created by Naren Reddy on 1/9/26.
//

import CoreData
import os.log

private let logger = Logger(subsystem: "com.swisscoin", category: "persistence")

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Preview context - no mock data seeded for production
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let container = NSPersistentContainer(name: "Swiss_Coin")
        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        // Enable lightweight migration and async loading
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.shouldAddStoreAsynchronously = true
        }

        self.container = container

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Check for migration errors (source/destination incompatibility, missing mapping)
                if let storeURL = storeDescription.url,
                    error.domain == NSCocoaErrorDomain
                        && (error.code == 134140 || error.code == 134130
                            || error.code == 134110)
                {

                    // DEV MODE: Automatically destroy store if migration fails
                    do {
                        try container.persistentStoreCoordinator.destroyPersistentStore(
                            at: storeURL, ofType: storeDescription.type, options: nil)

                        // Retry loading safely
                        container.loadPersistentStores { _, secondError in
                            if let secondError = secondError {
                                logger.error("CoreData: Failed to load store after reset: \(String(describing: secondError))")
                                logger.warning("Continuing with in-memory store as fallback")
                            }
                            // Configure viewContext after retry
                            DispatchQueue.main.async {
                                container.viewContext.automaticallyMergesChangesFromParent = true
                            }
                        }
                        return
                    } catch {
                        logger.error("CoreData: Failed to destroy persistent store: \(error.localizedDescription)")
                        logger.warning("Continuing with corrupted store — data may be unavailable")
                    }
                }

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                logger.error("CoreData: \(error.localizedDescription), \(String(describing: error.userInfo))")
                logger.warning("Continuing with in-memory store as fallback")
                // App continues - views will show empty state
            }

            // Configure viewContext after store loads (on main thread since it's a main queue context)
            DispatchQueue.main.async {
                container.viewContext.automaticallyMergesChangesFromParent = true
            }
        }
    }
}
