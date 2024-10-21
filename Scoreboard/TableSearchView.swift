//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

// TODO: indicate disabled, maybe make score data sortable

struct TableListView: View {

    let document: ScoreboardDocument
    @Binding var tables: [Table]

    @State private var sortOrder = [KeyPathComparator(\Table.name)]

    var body: some View {
        SwiftUI.Table(tables, sortOrder: $sortOrder) {
            TableColumn("Table", value: \.name) { table in
                NavigationLink(value: table) {
                    Text(table.name)
                }
            }
            .width(min: 200)

            TableColumn("Status", value: \.comparableScoreStatus) { table in
                Text(table.scoreStatus?.rawValue ?? "-")
            }
            TableColumn("Type", value: \.comparableScoreType) { table in
                Text(table.scoreType?.rawValue ?? "-")
            }
            TableColumn("Score") { table in
                let score = document.contents[table.scoreId]?.entries.first?.score
                Text(score?.formatted() ?? "-")
            }
            TableColumn("Count") { table in
                let count = document.contents[table.scoreId]?.entries.count
                Text(count?.formatted() ?? "-")
            }
        }
        .onChange(of: sortOrder) {
            tables.sort(using: sortOrder)
        }
    }
}

struct TableSearchView: View {

    let document: ScoreboardDocument

    @Binding var path: NavigationPath
    @Binding var search: String

    @State var items = [Table]()

    var body: some View {
        VStack {
            TableListView(document: document, tables: $items)
        }
        .toolbar {
            Button(action: showInCabinet) {
                Text("Search Cabinet")
            }
        }
        .searchable(text: $search)
        .onChange(
            of: search,
            { oldValue, newValue in
                performSearch(newValue)
            }
        )
        .onAppear {
            self.items = document.contents.tables.values.sorted()
            performSearch(search)
        }
    }

    private func showInCabinet() {
        Task {
            try await PinupPopper().search(search)
        }
    }

    private func performSearch(_ search: String) {
        if search.isEmpty {
            self.items = document.contents.tables.values.sorted()
        } else {
            let terms = search.lowercased()
            self.items = document.contents.tables.values
                .filter { table in
                    table.name.lowercased().contains(terms)
                }
                .sorted()
            if self.items.count == 1 {
                path.append(self.items[0])
            }
        }
    }

}
