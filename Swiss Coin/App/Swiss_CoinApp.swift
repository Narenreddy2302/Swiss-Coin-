//
//  Swiss_CoinApp.swift
//  Swiss Coin
//
//  Created by Naren Reddy on 1/9/26.
//

import BackgroundTasks
import CoreData
import SwiftUI
import UIKit
import UserNotifications

@main
struct Swiss_CoinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @AppStorage("theme_mode") private var themeMode = "system"
    @Environment(\.scenePhase) private var scenePhase

    private static let backgroundSyncTaskId = "com.swisscoin.background-sync"

    init() {
        registerBackgroundSync()
        configureTabBarAppearance()
        registerForPushNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(colorScheme)
                .tint(AppColors.accent)
                .onOpenURL { _ in
                    // Auth callbacks are handled by Supabase SDK automatically.
                    // No manual processing needed for native Apple Sign-In.
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AppLockManager.shared.appDidEnterBackground()
                scheduleBackgroundSync()
            case .active:
                AppLockManager.shared.appDidEnterForeground()
                if AuthManager.shared.authState == .authenticated {
                    // Re-verify Apple credential hasn't been revoked
                    Task { await AuthManager.shared.checkAppleCredentialState() }
                    let context = persistenceController.container.viewContext
                    SyncManager.shared.syncAll(context: context)

                    // Run contact discovery if stale (throttled to once per hour)
                    if ContactDiscoveryService.shared.shouldRunDiscovery {
                        Task {
                            await ContactDiscoveryService.shared.discoverContacts(context: context)
                        }
                    }
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

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        appearance.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "#2C2C2E")
                : UIColor(hex: "#F7F5F3")
        }

        appearance.shadowColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "#38383A")
                : UIColor(hex: "#F0EDEA")
        }

        let selected = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "#F36D30") : UIColor(hex: "#F35B16")
        }
        let unselected = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "#6B6560") : UIColor(hex: "#A8A29E")
        }

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = selected
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
        itemAppearance.normal.iconColor = unselected
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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

    // MARK: - Push Notifications

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Background Sync

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        guard AuthManager.shared.authState == .authenticated else {
            task.setTaskCompleted(success: false)
            return
        }

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

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        Task { @MainActor in
            guard let userId = AuthManager.shared.currentUserId else { return }
            try? await SupabaseDataService.shared.upsertDeviceToken(userId: userId, token: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Push registration failed — user can still use the app without push
    }
}
