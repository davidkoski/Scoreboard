//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

struct TableListView : View {
    
    let tables: [Table]
    
    var body: some View {
        List {
            ForEach(tables) { table in
                NavigationLink(table.name, value: table)
            }
        }
        .frame(minWidth: 200)
    }
    
}

struct TableSearchView: View {
    
    let document: ScoreboardDocument
    
    @State var search = ""
    @State var items = [Table]()
    
    var body: some View {
        VStack {
            TableListView(tables: items)
        }
        .toolbar {
            Button(action: applySearch) {
                Text("Search Pinbot")
            }
        }
        .searchable(text: $search)
        .onChange(of: search, { oldValue, newValue in
            performSearch(newValue)
        })
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
        }
    }

}
