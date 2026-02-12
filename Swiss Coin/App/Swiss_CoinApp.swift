//
//  Swiss_CoinApp.swift
//  Swiss Coin
//
//  Created by Naren Reddy on 1/9/26.
//

import SwiftUI
import CoreData

@main
struct Swiss_CoinApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("theme_mode") private var themeMode = "system"
    @Environment(\.scenePhase) private var scenePhase

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
            case .active:
                AppLockManager.shared.appDidEnterForeground()
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
}
