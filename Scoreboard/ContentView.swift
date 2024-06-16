//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI
import SwiftData

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
                case "Current":
                    CurrentTableDetailView()
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
            Button(action: selectCurrent) {
                Text("Current")
            }
        }
        .onAppear() {
            modelContext.autosaveEnabled = true
            path.append("Recent")
        }
    }
    
    private func selectCurrent() {
        Task {
            do {
                guard let current = try await PinupPopper().currentTable() else {
                    print("Unable to get current from PinupPopper")
                    return
                }
                let id = current.id
                
                let tables = try modelContext.fetch(FetchDescriptor<Table>(predicate: #Predicate<Table> {
                    $0.id == id
                }))
                
                let table = tables.first ?? Table(id: current.id, name: current.name, popperId: current.gameID)
                
                // backfill missing popperId
                if table.popperId == nil {
                    table.popperId = current.gameID
                }
                
                if path.isEmpty {
                    path.removeLast()
                }
                path.append(table)
            } catch {
                print("Unable to get current: \(error)")
            }
        }
    }
}
