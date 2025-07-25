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

    @State var search = ""

    @State var busy = false
    @State var current: String?
    @State var messages = [String]()

    enum Tab: String, Hashable, CaseIterable, Identifiable {
        case recent
        case tables
        case dups

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .recent: "clock"
            case .tables: "table.furniture"
            case .dups: "square.stack"
            }
        }
    }
    @State var tab = Tab.recent
    @State var tabState = [Tab: NavigationPath]()

    var path: Binding<NavigationPath> {
        Binding {
            tabState[tab] ?? .init()
        } set: {
            tabState[tab] = $0
        }

    }

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
        NavigationStack(path: path) {
            Group {
                switch tab {
                case .recent:
                    RecentScoresView(document: document)
                case .tables:
                    TableSearchView(document: document, path: path, search: $search)
                case .dups:
                    DuplicatesView(document: $document)
                }
            }
            .navigationDestination(for: Table.self) { table in
                TableDetailView(
                    document: document, path: path, search: $search,
                    table: tableBinding(table), scores: scoreBinding(table))
            }
        }
        .toolbar {
            ForEach(Tab.allCases) { tab in
                Button(action: { self.tab = tab }) {
                    Image(systemName: tab.systemImage)
                }
                .buttonStyle(.plain)
                .bold(self.tab == tab)
            }
            VPinStudioScanner(
                document: $document, busy: $busy, current: $current, messages: $messages)
            Button(action: selectCurrent) {
                Text("Current")
            }
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
                    if !path.wrappedValue.isEmpty {
                        path.wrappedValue.removeLast()
                    }
                    path.wrappedValue.append(table)
                }
            } catch {
                print("Unable to get current: \(error)")
            }
        }
    }
}
