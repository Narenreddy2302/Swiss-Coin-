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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
