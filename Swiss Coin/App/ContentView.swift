//
//  ContentView.swift
//  Swiss Coin
//
//  Main content view that handles authentication routing.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    var body: some View {
        Group {
            switch supabase.authState {
            case .unknown:
                // Loading state while checking authentication
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .authenticated:
                // User is logged in - show main app
                MainTabView()

            case .unauthenticated, .verifyingOTP:
                // User needs to log in
                PhoneLoginView()
            }
        }
        .animation(.easeInOut, value: supabase.authState)
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
