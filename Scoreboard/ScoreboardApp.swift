//
//  ScoreboardApp.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static var scoreboards = UTType(exportedAs: "com.koski.scoreboards")
}

@main
struct ScoreboardApp: App {
    
    @State var pinballDB = PinballDB()
    
    var body: some Scene {
        DocumentGroup(
            editing: .scoreboards,
            migrationPlan: ScoreboardCardsMigrationPlan.self) {
            ContentView()
                .environmentObject(pinballDB)
        }

        WindowGroup {
            ContentView()
        }
    }
}
