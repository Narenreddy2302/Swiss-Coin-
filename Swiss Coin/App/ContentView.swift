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

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                // Loading state while checking authentication
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .authenticated:
                // User is logged in — show main app
                MainTabView()

            case .unauthenticated:
                // User needs to log in — show welcome screen
                PhoneLoginView()
            }
        }
        .animation(AppAnimation.standard, value: authManager.authState)
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
