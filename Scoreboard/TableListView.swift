//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI
import SwiftData

struct SearchItem : Identifiable, Hashable, Comparable {
    let table: Table
    let entry: PinballDB.Entry
    
    var id: String { entry.id }
    var name: String { entry.title }
    
    var hasScores: Bool { !table.scores.isEmpty }
    
    static func < (lhs: SearchItem, rhs: SearchItem) -> Bool {
        func trim(_ s: String) -> String {
            s
                .lowercased()
                .replacingOccurrences(of: "the ", with: "")
                .replacingOccurrences(of: "jp's ", with: "")
        }
        return trim(lhs.entry.name) < trim(rhs.entry.name)
    }
}

struct TableListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [Table]
    
    @State var search = ""
    @State var items = [SearchItem]()
    @State var selected: SearchItem?
    
    enum SearchState {
        case idle
        case searching
        case staleSearch(String)
    }
    @State var searchState = SearchState.idle
    
    @State var show = Show.table
    
    @EnvironmentObject var pinballDB: PinballDB
    
    var body: some View {
        VStack {
            NavigationSplitView {
                List(selection: $selected) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            Text(item.name)
                                .bold(item.hasScores)
                        }
                    }
                }
                .frame(minWidth: 200)
            } detail: {
                if let selected {
                    TableDetailView(entry: selected.entry, table: selected.table, show: $show)
                        .padding()
                } else {
                    RecentScoresView(selected: $selected)
                }
            }
        }
        .toolbar {
            Button(action: goToCurrent) {
                Text("Current")
            }
            Button(action: applySearch) {
                Text("Search Pinbot")
            }
        }
        .searchable(text: $search)
        .onChange(of: search, { oldValue, newValue in
            performSearch(newValue)
        })
        .task {
            try? await pinballDB.load()
            items = await Array(tables
                .async
                .compactMap {
                    if let entry = try? await pinballDB.find(id: $0.id) {
                        return SearchItem(table: $0, entry: entry)
                    } else {
                        return nil
                    }
                }
            )
            .sorted()
        }
    }
    
    private func goToCurrent() {
        Task {
            do {
                guard let current = try await PinupPopper().currentTable() else {
                    print("Unable to get current from PinupPopper")
                    return
                }
                
                guard let entry = try await pinballDB.find(id: current.id) else {
                    print("Unable to get pinballDB entry for \(current.id)")
                    return
                }
                
                let table = self.tables.first { $0.id == current.id } ??
                    .init(entry)
                
                if table.popperId == nil {
                    table.popperId = current.gameID
                    try modelContext.save()
                }
                
                items = [SearchItem(table: table, entry: entry)]
                selected = items[0]
            } catch {
                print("Unable to get current: \(error)")
            }
        }
    }
    
    private func applySearch() {
        Task {
            try await PinupPopper().search(search)
        }
    }
        
    @MainActor
    private func performSearch(_ search: String) {
        switch searchState {
        case .idle:
            searchState = .searching
            Task {
                let tables = Dictionary(uniqueKeysWithValues: self.tables.map { ($0.id, $0) })
                
                if let entries = try? await pinballDB.find(search.lowercased()) {
                    self.items = entries
                        .map { entry in
                            if let table = tables[entry.id] {
                                return SearchItem(table: table, entry: entry)
                            } else {
                                return SearchItem(table: Table(entry), entry: entry)
                            }
                        }
                        .sorted()
                }
                
                await MainActor.run {
                    switch searchState {
                    case .idle, .searching:
                        searchState = .idle
                    case .staleSearch(let string):
                        searchState = .idle
                        performSearch(string)
                    }
                }
            }
        case .searching, .staleSearch:
            searchState = .staleSearch(search)
        }
    }

}
