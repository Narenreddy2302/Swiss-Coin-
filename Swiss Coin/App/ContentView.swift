//
//  ContentView.swift
//  Swiss Coin
//
//  Main content view that handles app routing, auth gating, and lock screen.
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
    @State private var hasStartedServices = false

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                loadingView
            case .unauthenticated:
                SignInView()
            case .authenticated:
                authenticatedContent
            }
        }
        .animation(AppAnimation.standard, value: authManager.authState)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ProgressView()
                .tint(AppColors.accent)
        }
    }

    // MARK: - Authenticated Content

    private var authenticatedContent: some View {
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
            startServicesIfNeeded()
        }
        .onChange(of: hasSeenOnboarding) { _, _ in
            startServicesIfNeeded()
        }
    }

    // MARK: - Services

    private func startServicesIfNeeded() {
        guard hasSeenOnboarding, !hasStartedServices else { return }
        hasStartedServices = true
        Task {
            await RealtimeService.shared.subscribe()
            await SyncManager.shared.syncNow(context: viewContext)
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
