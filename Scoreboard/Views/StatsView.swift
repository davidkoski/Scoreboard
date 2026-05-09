//
//  TimeView.swift
//  Scoreboard
//
//  Created by David Koski on 8/30/25.
//

import Foundation
import SwiftUI

private struct StatsItem: Identifiable {
    let id = UUID()

    let group: String

    var tableCount = 0
    var plays: Activity.Snapshot
    var scores = 0
    var place1 = 0
    var place2 = 0
    var place3 = 0

    init(group: String) {
        self.group = group
        self.plays = .init()
    }

    mutating func add(plays: Activity.Snapshot, scores: TableScoreboard) {
        tableCount += 1

        self.plays += plays

        self.scores += scores.localCount
        if scores.entries.count > 0 {
            if scores.entries[0].isLocal {
                place1 += 1
            }
        }
        if scores.entries.count > 1 {
            if scores.entries[1].isLocal {
                place2 += 1
            }
        }
        if scores.entries.count > 2 {
            if scores.entries[2].isLocal {
                place3 += 1
            }
        }
    }
}

private struct StatsCollator: Identifiable, Sendable, Hashable {
    let id = UUID()
    let name: String
    let grouper: @Sendable (Table) -> String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StatsCollator, rhs: StatsCollator) -> Bool {
        return lhs.id == rhs.id
    }
}

private let collators: [StatsCollator] = [
    .init(name: "Kind") { $0.gameType.rawValue },
    .init(name: "Year") { $0.gameYear.description },
    .init(name: "Decade") { ($0.gameYear / 10 % 10 * 10).description },
    .init(name: "Manufacturer") { $0.manufacturer },
    .init(name: "Author") { $0.firstAuthor },
]

struct StatsView: View {

    let document: ScoreboardDocument

    @Binding var items: [TableItem]
    @State private var filteredItems = [StatsItem]()

    @State private var collator = collators[0]
    @State private var sortOrder = [KeyPathComparator(\StatsItem.group)]

    var body: some View {
        VStack {
            Picker("Collator", selection: $collator) {
                ForEach(collators) {
                    Text($0.name).tag($0)
                }
            }
            SwiftUI.Table(filteredItems, sortOrder: $sortOrder) {
                TableColumn("Group", value: \.group)
                TableColumn("Tables", value: \.tableCount) {
                    Text("\($0.tableCount)")
                }
                TableColumn("Plays", value: \.plays.numberOfPlays) {
                    Text("\($0.plays.numberOfPlays.formatted())")
                }
                TableColumn("Time", value: \.plays.timePlayedSecs) {
                    Text("\($0.plays.timePlayedSecs.description)")
                }
                TableColumn("Scores", value: \.scores) {
                    Text("\($0.scores)")
                }
                TableColumn("1st", value: \.place1) {
                    Text("\($0.place1)")
                }
                TableColumn("2nd", value: \.place2) {
                    Text("\($0.place2)")
                }
                TableColumn("3rd", value: \.place3) {
                    Text("\($0.place3)")
                }
            }
        }
        .onChange(of: sortOrder) {
            filteredItems.sort(using: sortOrder)
        }
        .task(id: document.serialNumber) {
            filter()
        }
        .onChange(of: items) {
            filter()
        }
        .onChange(of: collator) {
            filter()
        }
    }

    func filter() {
        var build = [String: StatsItem]()

        for item in items {
            guard let group = collator.grouper(item.table) else { continue }

            let plays = document.contents.activity.snapshots[item.table.id] ?? .init()
            let scores = document.contents.scores[item.table.scoreId] ?? .init(item.table)

            build[group, default: .init(group: group)].add(plays: plays, scores: scores)
        }

        filteredItems = build.values.sorted(using: sortOrder)
    }
}
