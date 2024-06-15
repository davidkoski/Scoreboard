//
//  RecentScoresView.swift
//  Scoreboard
//
//  Created by David Koski on 5/29/24.
//

import Foundation
import SwiftUI
import SwiftData

struct RecentScoresView : View {
    
    @Binding var selected: SearchItem?
    @EnvironmentObject var pinballDB: PinballDB

    @Environment(\.modelContext) private var modelContext
    
    @Query
    private var scores: [Score]

    @State private var sortOrder = [KeyPathComparator(\Score.date, order: .reverse)]
    
    init(selected: Binding<SearchItem?>) {
        self._selected = selected
        
        let recent = Date() - 2 * 3600 * 24
        self._scores = Query(
            filter: #Predicate<Score> {
                $0.date > recent
            })
    }

    var body: some View {
        SwiftUI.Table(scores.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("Table") { score in
                HStack {
                    Button(action: { select(score) }) {
                        Image(systemName: "arrow.forward")
                    }
                    Text(score.table?.name ?? "-")
                }
            }
                .width(min: 200)

            TableColumn("Name", value: \.person)
                .width(min: 50, max: 50)
            
            TableColumn("Score", value: \.score) { score in
                Text(score.score.formatted())
            }
            TableColumn("Date", value: \.date) { score in
                Text(score.date.formatted())
            }
        }
    }
    
    private func select(_ score: Score) {
        if let table = score.table {
            Task {
                if let entry = try await pinballDB.find(id: table.id) {
                    selected = SearchItem(table: table, entry: entry)
                }
            }
        }
    }
}
