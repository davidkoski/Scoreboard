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

    @Binding var items: [TableItem]
    @State private var filteredItems = [TableItem]()

    var body: some View {
        VStack {
            TableListView(document: document, items: $filteredItems, showLastScoreDate: true)
        }
        .task(id: document.serialNumber) {
            filter()
        }
        .onChange(of: items) {
            filter()
        }
    }

    func filter() {
        let recent = Date() - 3 * 24 * 3600

        filteredItems = items.filter { item in
            guard let lastScoreDate = item.lastScoreDate, lastScoreDate > recent else {
                return false
            }

            return true
        }
    }
}
