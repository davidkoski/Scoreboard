//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI

struct ContentView: View {

    @Binding var document: ScoreboardDocument

    @State var path = NavigationPath()
    @State var search = ""

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

    func scoreBinding(_ table: Table) -> Binding<TableScoreboard> {
        Binding {
            document.contents[score: table]
        } set: { newValue in
            document.contents[score: table] = newValue
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Recent", value: "Recent")
                NavigationLink("Tables", value: "Tables")
                NavigationLink("Duplicates", value: "Duplicates")
            }
            .navigationDestination(for: String.self) { key in
                switch key {
                case "Recent":
                    RecentScoresView(document: document)
                case "Tables":
                    TableSearchView(document: document, path: $path, search: $search)
                case "Duplicates":
                    DuplicatesView(document: $document)
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: Table.self) { table in
                TableDetailView(
                    document: document, path: $path,
                    table: tableBinding(table), scores: scoreBinding(table))
            }
        }
        .toolbar {
            VPinStudioScanner(
                document: $document, busy: $busy, current: $current, messages: $messages)
            Button(action: selectCurrent) {
                Text("Current")
            }
        }
        .onAppear {
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

    @MainActor
    private func selectCurrent() {
        Task {
            do {
                guard let id = try await PinupPopper().currentTableId() else {
                    print("Unable to get current from PinupPopper")
                    return
                }

                if let table = document[id] {
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
