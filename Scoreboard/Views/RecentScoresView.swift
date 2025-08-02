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

    @State private var items = [TableItem]()

    var body: some View {
        VStack {
            TableListView(document: document, items: $items, showLastScoreDate: true)
        }
        .task(id: document.serialNumber) {
            var tables = [Table]()
            let recent = Date() - 3 * 24 * 3600

            for (id, scores) in document.contents.scores {
                if let bestScore = scores.best(), bestScore.date > recent,
                    let table = document.contents.representative(id)
                {
                    tables.append(table)
                }
            }

            self.items = tables.sorted().map { .init(table: $0, document: document) }
        }
    }

}
