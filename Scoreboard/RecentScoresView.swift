//
//  RecentScoresView.swift
//  Scoreboard
//
//  Created by David Koski on 5/29/24.
//

import Foundation
import SwiftUI

struct ScoreTable: Identifiable {
    let score: Score
    let table: Table
    var id = UUID()
}

struct RecentScoresView: View {

    let document: ScoreboardDocument

    @State private var scores = [ScoreTable]()
    @State private var sortOrder = [KeyPathComparator(\ScoreTable.score.date, order: .reverse)]

    var body: some View {
        SwiftUI.Table(scores, sortOrder: $sortOrder) {
            TableColumn("Table", value: \.table.name) { st in
                NavigationLink(value: st.table) {
                    Text(st.table.name)
                }
            }
            .width(min: 200)

            TableColumn("Initials", value: \.score.initials)
                .width(min: 50, max: 50)

            TableColumn("Score", value: \.score) { st in
                Text(st.score.score.formatted())
            }
            TableColumn("Date", value: \.score.date) { st in
                Text(st.score.date.formatted())
            }
        }
        .onChange(of: sortOrder) {
            scores.sort(using: sortOrder)
        }
        .task {
            var result = [ScoreTable]()
            let recent = Date() - 3 * 24 * 3600

            for (id, scores) in document.contents.scores {
                let bestScore = scores.best()
                if let bestScore = scores.best(), bestScore.date > recent,
                    let table = document.contents.representative(id)
                {
                    result.append(ScoreTable(score: bestScore, table: table))
                }
            }

            self.scores = result.sorted(using: sortOrder)
        }
    }
}
