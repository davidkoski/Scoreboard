//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
    
    @Query private var tables: [Table]
    
    @State var search = ""
    @State var items = [Table]()
    
    var body: some View {
        VStack {
            TableListView(tables: items.sorted())
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
        .task {
            self.items = tables
        }
    }
        
    private func applySearch() {
        Task {
            try await PinupPopper().search(search)
        }
    }
        
    private func performSearch(_ search: String) {
        let terms = search.lowercased()
        self.items = tables
            .filter { table in
                table.name.lowercased().contains(terms)
            }
    }

}
