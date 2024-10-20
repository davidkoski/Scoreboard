//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

struct TableListView: View {

    let document: ScoreboardDocument
    let tables: [Table]

    var body: some View {
        List {
            ForEach(tables) { table in
                NavigationLink(value: table) {
                    HStack {
                        Text(table.name)
                            .frame(width: 500, alignment: .leading)

                        Text(table.scoreStatus?.rawValue ?? "-")
                            .frame(width: 100, alignment: .leading)

                        if let score = document.contents[table.scoreId]?.entries.first {
                            Text(score.score.formatted())
                                .frame(width: 250, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

}

struct TableSearchView: View {

    let document: ScoreboardDocument

    @Binding var path: NavigationPath
    @Binding var search: String

    @State var items = [Table]()

    var body: some View {
        VStack {
            TableListView(document: document, tables: items)
        }
        .toolbar {
            Button(action: applySearch) {
                Text("Search Pinbot")
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

    private func applySearch() {
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
