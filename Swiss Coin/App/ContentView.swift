//
//  ContentView.swift
//  Swiss Coin
//
//  Main content view that handles authentication routing and app lock screen.
//  The lock screen gates the UI while data preloads behind it — modeled after
//  Cash App and Revolut for an instant-feeling unlock experience.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var lockManager = AppLockManager.shared
    @StateObject private var migrationService = MigrationService.shared
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack {
            // Layer 1: Main app content (renders behind the lock screen so
            // @FetchRequest results and view state are warm on unlock)
            Group {
                switch authManager.authState {
                case .unknown:
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .authenticated:
                    if hasSeenOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView()
                    }

                case .unauthenticated:
                    PhoneLoginView()
                }
            }

            // Layer 2: Lock screen overlay
            // Only shown for authenticated users who have security enabled
            if authManager.authState == .authenticated
                && hasSeenOnboarding
                && lockManager.lockState != .unlocked
                && lockManager.isSecurityEnabled
            {
                LockScreenView(lockManager: lockManager)
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Layer 3: Migration overlay (first sign-in with existing local data)
            if migrationService.progress == .inProgress {
                MigrationOverlayView(migrationService: migrationService)
                    .transition(.opacity)
                    .zIndex(200)
            }
        }
        .animation(AppAnimation.standard, value: authManager.authState)
        .animation(AppAnimation.standard, value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.3), value: lockManager.lockState)
        .onAppear {
            if authManager.authState == .authenticated {
                lockManager.performInitialLockCheck()
            }
        }
        .onChange(of: authManager.authState) { _, newState in
            if newState == .authenticated {
                lockManager.performInitialLockCheck()
                Task {
                    // Migrate local data to Supabase if needed (first sign-in with existing data)
                    if MigrationService.shared.needsMigration {
                        await MigrationService.shared.migrate(context: viewContext)
                    }
                    // Start realtime subscription and initial sync
                    await RealtimeService.shared.subscribe()
                    await SyncManager.shared.syncNow(context: viewContext)
                }
            } else if newState == .unauthenticated {
                Task {
                    await RealtimeService.shared.unsubscribe()
                }
            }
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
