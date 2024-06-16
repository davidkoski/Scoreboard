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
                NavigationLink("Recent", value: "Recent")
                NavigationLink("Tables", value: "Tables")
                NavigationLink("Tags", value: "Tags")
            }
            .navigationDestination(for: String.self) { key in
                switch key {
                case "Recent":
                    RecentScoresView()
                case "Tables":
                    TableSearchView()
                case "Tags":
                    TagListView()
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: Table.self) { table in
                TableDetailView(table: table)
            }
            .navigationDestination(for: Tag.self) { tag in
                TableListView(tables: tag.tables.sorted())
            }
        }
        .toolbar {
            NavigationLink {
                CurrentTableDetailView()
            } label: {
                Text("Current")
            }

        }
        .onAppear() {
            modelContext.autosaveEnabled = true
            path.append("Recent")
        }
    }
}
