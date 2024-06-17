//
//  RecentScoresView.swift
//  Scoreboard
//
//  Created by David Koski on 5/29/24.
//

import Foundation
import SwiftUI

struct ScoreTable : Identifiable, Comparable {
    let score: Score
    let table: Table
    var id: Date { score.date }
    
    static func < (lhs: ScoreTable, rhs: ScoreTable) -> Bool {
        lhs.score.date > rhs.score.date
    }
}

struct RecentScoresView : View {

    let document: ScoreboardDocument
    
    @State var scores = [ScoreTable]()

    var body: some View {
        SwiftUI.Table(scores) {
            TableColumn("Table") { st in
                NavigationLink(value: st.table) {
                    Text(st.table.name)
                }
            }
                .width(min: 200)

            TableColumn("Initials", value: \.score.initials)
                .width(min: 50, max: 50)
            
            TableColumn("Score") { st in
                Text(st.score.score.formatted())
            }
            TableColumn("Date") { st in
                Text(st.score.date.formatted())
            }
        }
        .task {
            var scores = [ScoreTable]()
            let recent = Date() - 3 * 24 * 3600
            
            for table in document.contents.tables.values {
                let recentScores = table.scores.filter { $0.date > recent }
                if !recentScores.isEmpty {
                    scores.append(
                        contentsOf:
                            recentScores.map { ScoreTable(score: $0, table: table) }
                    )
                }
            }
            
            self.scores = scores.sorted()
        }
    }
}
