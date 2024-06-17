//
//  ScoreboardApp.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

@main
struct ScoreboardApp: App {
    
    var body: some Scene {
        DocumentGroup(newDocument: ScoreboardDocument(), editor: { configuration in
            ContentView(document: configuration.$document)
        })
    }
}
