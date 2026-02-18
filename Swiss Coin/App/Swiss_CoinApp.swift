//
//  Swiss_CoinApp.swift
//  Swiss Coin
//
//  Created by Naren Reddy on 1/9/26.
//

import BackgroundTasks
import CoreData
import SwiftUI

@main
struct Swiss_CoinApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("theme_mode") private var themeMode = "system"
    @Environment(\.scenePhase) private var scenePhase

    private static let backgroundSyncTaskId = "com.swisscoin.background-sync"

    init() {
        registerBackgroundSync()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(colorScheme)
                .tint(AppColors.accent)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AppLockManager.shared.appDidEnterBackground()
                scheduleBackgroundSync()
            case .active:
                AppLockManager.shared.appDidEnterForeground()
                // Trigger sync when app becomes active
                if AuthManager.shared.authState == .authenticated {
                    let context = persistenceController.container.viewContext
                    SyncManager.shared.syncAll(context: context)
                }
            default:
                break
            }
        }
    }

    /// Returns the appropriate color scheme based on user preference
    private var colorScheme: ColorScheme? {
        switch themeMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
        }
    }

    // MARK: - Background Sync

    private func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundSyncTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleBackgroundSync(task: refreshTask)
        }
    }

    private func scheduleBackgroundSync() {
        guard AuthManager.shared.authState == .authenticated else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling can fail silently (e.g., low power mode)
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        scheduleBackgroundSync() // Schedule the next one

        let syncTask = Task {
            let context = persistenceController.newBackgroundContext()
            await SyncManager.shared.syncNow(context: context)
        }

        task.expirationHandler = {
            syncTask.cancel()
        }

        Task {
            await syncTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
