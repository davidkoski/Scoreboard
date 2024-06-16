//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI

struct ContentView : View {
    
    @State var path = NavigationPath()
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Tables", value: "Tables")
                NavigationLink("Tags", value: "Tags")
            }
            .navigationDestination(for: String.self) { key in
                switch key {
                case "Tables":
                    TableListView()
                case "Tags":
                    TagListView()
                default:
                    EmptyView()
                }
            }
        }
        .onAppear() {
            modelContext.autosaveEnabled = true
            path.append("Tables")
        }
    }
}
