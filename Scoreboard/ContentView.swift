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
    
    @State var busy = false
    @State var current: String?
    @State var messages = [String]()
    
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
            Button(action: scanTables) {
                Text("􀚁 Tables")
            }
            Button(action: scanScores) {
                Text("􀚁 Scores")
            }
            Button(action: selectCurrent) {
                Text("Current")
            }
        }
        .onAppear() {
            path.append("Recent")
        }
        .overlay {
            if busy || !messages.isEmpty {
                VStack {
                    if busy {
                        ProgressView()
                        if let current {
                            Text(current)
                        }
                    }
                    if !messages.isEmpty {
                        Button(action: { messages.removeAll() }) {
                            Text("OK")
                        }

                        List {
                            ForEach(messages, id: \.self) { message in
                                Text(message)
                            }
                        }
                        
                        Button(action: { messages.removeAll() }) {
                            Text("OK")
                        }
                    }
                }
                .padding()
                .border(Color.secondary)
                .background(Color("background"))
            }
        }
    }
    
    private func scanTables() {
        Task {
            do {
                busy = true
                current = "Fetching tables..."
                let tables = try await VPinStudio().getTablesList()
                current = "Merging tables..."
                for table in tables {
                    if let existing = document.contents.tables[table.id] {
                        if existing.name != table.gameName || existing.popperId == nil {
                            messages.append("Rename \(existing.name) -> \(table.gameName)")
                            document[existing].name = table.gameName
                            document[existing].popperId = table.popperId
                        }
                    } else {
                        messages.append("New \(table.gameName)")
                        let new = Table(id: table.id, name: table.gameName, popperId: table.popperId)
                        document[new] = new
                    }
                }
            } catch {
                print("Unable to scanTables: \(error)")
            }
            busy = false
        }
    }
    
    private func scanScores() {
        Task {
            do {
                busy = true
                let client = VPinStudio()
                try await withThrowingTaskGroup(of: (Table, Score)?.self) { group in
                    current = "Sending requests..."
                    
                    for table in document.contents.tables.values {
                        if let id = table.popperId {
                            group.addTask {
                                let scores = try await client.getScores(id: id)
                                if let best = bestScore(scores) {
                                    // skip duplicates
                                    if !table.scores.contains(where: { $0.score == best.numericScore }) {
                                        return (table, .init(initials: "DAK", score: best.numericScore))
                                    }
                                }
                                
                                return nil
                            }
                        }
                    }
                    
                    let count = document.contents.tables.count
                    var i = 0
                    
                    for try await pair in group {
                        i += 1
                        current = "\(i)/\(count)"
                        
                        if let (table, score) = pair {
                            messages.append("\(table.name): \(score.score)")
                            document[table].scores.append(score)
                            document[table].scores.sort()
                        }
                    }
                }
            } catch {
                print("Unable to scanScores: \(error)")
            }
            busy = false
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
                
                await MainActor.run {
                    let table: Table
                    
                    if var existing = document[id] {
                        // backfill missing popperId
                        if existing.popperId == nil {
                            document[existing].popperId = current.gameID
                            existing = document[existing]
                        }
                        table = existing
                    } else {
                        table = Table(id: current.id, name: current.trimmedName, popperId: current.gameID)
                    }
                    
                    if !path.isEmpty {
                        path.removeLast()
                    }
                    path.append(table)
                }
            } catch {
                print("Unable to get current: \(error)")
            }
        }
    }
}
