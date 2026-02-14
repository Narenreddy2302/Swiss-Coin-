//
//  RefreshHelper.swift
//  Swiss Coin
//
//  Centralized pull-to-refresh handler for CoreData-backed views.
//

import CoreData
import SwiftUI

enum RefreshHelper {
    /// Standard pull-to-refresh handler for any CoreData-backed view.
    /// Invalidates all faulted objects, waits for the spinner animation to complete, and provides haptic feedback.
    static func performStandardRefresh(context: NSManagedObjectContext) async {
        guard context.persistentStoreCoordinator?.persistentStores.isEmpty == false else {
            return
        }
        context.refreshAllObjects()
        try? await Task.sleep(nanoseconds: 300_000_000)
        await MainActor.run {
            HapticManager.lightTap()
        }
    }
}
