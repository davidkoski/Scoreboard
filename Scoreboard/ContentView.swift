//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI

struct ContentView : View {

    @Binding var document: ScoreboardDocument

    @State var path = NavigationPath()
    
    func tableBinding(_ table: Table) -> Binding<Table> {
        Binding {
            document[table]
        } set: { newValue in
            document[table] = newValue
        }
    }
        
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
                    RecentScoresView(document: document)
                case "Tables":
                    TableSearchView(document: document)
                case "Tags":
                    TagListView(document: $document)
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: Table.self) { table in
                TableDetailView(table: tableBinding(table), tags: document.contents.tags)
            }
            .navigationDestination(for: Tag.self) { tag in
                let tables = document.contents.tables.values
                    .filter { $0.tags.contains(tag.tag) }
                    .sorted()
                TableListView(tables: tables)
            }
        }
        .toolbar {
            Button(action: selectCurrent) {
                Text("Current")
            }
        }
        .onAppear() {
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
                
                var table = document[id] ?? Table(id: current.id, name: current.name, popperId: current.gameID)
                                
                // backfill missing popperId
                if table.popperId == nil {
                    document[table].popperId = current.gameID
                    table = document[table]
                }
                
                if !path.isEmpty {
                    path.removeLast()
                }
                path.append(table)
            } catch {
                print("Unable to get current: \(error)")
            }
        }
    }
}
