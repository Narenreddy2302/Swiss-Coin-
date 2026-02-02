//
//  ContentView.swift
//  Swiss Coin
//
//  Main content view that handles authentication routing.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                // Loading state while checking authentication
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .authenticated:
                if hasSeenOnboarding {
                    // User has completed onboarding — show main app
                    MainTabView()
                } else {
                    // First launch — show onboarding walkthrough
                    OnboardingView()
                }

            case .unauthenticated:
                // User needs to log in — show welcome screen
                PhoneLoginView()
            }
        }
        .animation(AppAnimation.standard, value: authManager.authState)
        .animation(AppAnimation.standard, value: hasSeenOnboarding)
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
