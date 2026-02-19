//
//  ContentView.swift
//  Swiss Coin
//
//  Main content view that handles app routing and lock screen.
//  The lock screen gates the UI while data preloads behind it — modeled after
//  Cash App and Revolut for an instant-feeling unlock experience.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var lockManager = AppLockManager.shared
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack {
            // Layer 1: Main app content (renders behind the lock screen so
            // @FetchRequest results and view state are warm on unlock)
            Group {
                if hasSeenOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }

            // Layer 2: Lock screen overlay
            // Only shown for authenticated users who have security enabled
            if hasSeenOnboarding
                && lockManager.lockState != .unlocked
                && lockManager.isSecurityEnabled
            {
                LockScreenView(lockManager: lockManager)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(AppAnimation.standard, value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.3), value: lockManager.lockState)
        .onAppear {
            lockManager.performInitialLockCheck()
        }
        .onChange(of: hasSeenOnboarding) { _, newValue in
            if newValue {
                Task {
                    // Start realtime subscription and initial sync
                    await RealtimeService.shared.subscribe()
                    await SyncManager.shared.syncNow(context: viewContext)
                }
            }
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
