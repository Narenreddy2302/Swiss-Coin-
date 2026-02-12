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
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false

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
            }
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
