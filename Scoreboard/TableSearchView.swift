//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

private struct TableItem: Identifiable {
    let table: Table
    let scoreCount: Int
    let score: Int
    let rank: Int

    var id: CabinetTableId { table.id }

    init(table: Table, document: ScoreboardDocument) {
        self.table = table
        let scoreboard = document.contents[table.scoreId]
        self.scoreCount = scoreboard?.localCount ?? 0
        self.score = scoreboard?.best()?.score ?? 0
        self.rank = scoreboard?.rank() ?? 0
    }
}

private struct TableListView: View {

    let document: ScoreboardDocument
    @Binding var items: [TableItem]

    @State private var sortOrder = [KeyPathComparator(\TableItem.table.name)]

    var body: some View {
        SwiftUI.Table(items, sortOrder: $sortOrder) {
            TableColumn("Table", value: \.table.name) { item in
                let table = item.table
                NavigationLink(value: table) {
                    Text(table.name).italic(table.disabled)
                }
            }
            .width(min: 230)

            TableColumn("Status", value: \.table.comparableScoreStatus) { item in
                let table = item.table
                if table.disabled {
                    Text("disabled").italic()
                } else {
                    Text(table.scoreStatus?.rawValue ?? "-")
                }
            }
            TableColumn("Type", value: \.table.comparableScoreType) { item in
                let table = item.table
                Text(table.scoreType?.rawValue ?? "-")
            }
            TableColumn("Score", value: \.score) { item in
                if item.score == 0 {
                    Text("-")
                } else {
                    Text(item.score.formatted())
                }
            }
            TableColumn("Rank", value: \.rank) { item in
                if item.rank == 0 {
                    Text("-")
                } else {
                    Text(item.rank.formatted())
                }
            }
            TableColumn("Count", value: \.scoreCount) { item in
                if item.scoreCount == 0 {
                    Text("-")
                } else {
                    Text(item.scoreCount.formatted())
                }
            }
        }
        .onChange(of: sortOrder) {
            items.sort(using: sortOrder)
        }
    }
}

struct TableSearchView: View {

    let document: ScoreboardDocument

    @Binding var path: NavigationPath
    @Binding var search: String

    @State private var items = [TableItem]()

    private func setTables(_ tables: any Sequence<Table>) {
        self.items = tables.sorted().map { .init(table: $0, document: document) }
    }

    var body: some View {
        VStack {
            TableListView(document: document, items: $items)
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
            setTables(document.contents.tables.values)
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
            setTables(document.contents.tables.values)
        } else {
            let terms = search.lowercased()
            setTables(
                document.contents.tables.values
                    .filter { table in
                        table.name.lowercased().contains(terms)
                    })
            if self.items.count == 1 {
                path.append(self.items[0].table)
            }
        }
    }

}
