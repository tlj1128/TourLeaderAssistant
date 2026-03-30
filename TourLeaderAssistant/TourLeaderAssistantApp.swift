//
//  TourLeaderAssistantApp.swift
//  TourLeaderAssistant
//
//  Created by 杜立仁 on 2026/3/30.
//

import SwiftUI
import SwiftData

@main
struct TourLeaderAssistantApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
