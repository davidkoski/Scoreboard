//
//  NVRamView.swift
//  Scoreboard
//
//  Created by David Koski on 8/15/24.
//

import Foundation
import SwiftUI

/// we need this wrapper so we have a distinct type for the navigationDestination
struct NVRam: Hashable, Identifiable, Comparable {
    let key: String

    var id: String { key }

    init?(_ key: String?) {
        if let key {
            self.key = key
        } else {
            return nil
        }
    }

    static func < (lhs: NVRam, rhs: NVRam) -> Bool {
        lhs.key < rhs.key
    }
}

struct DuplicatesView: View {

    @Binding var document: ScoreboardDocument

    @State var counts: [ScoreId: Int] = [:]

    @State var needsPrimary: Set<ScoreId> = []
    @State var allMatch: Set<ScoreId> = []
    @State var allEnabledMatch: Set<ScoreId> = []
    @State var primary: [ScoreId: String] = [:]

    var body: some View {
        VStack {
            List {
                let counts = counts.sorted { $0.key < $1.key }
                ForEach(counts, id: \.key) { key, count in
                    NavigationLink(value: key) {
                        HStack {
                            Text("\(key) (\(count))")
                            
                            if needsPrimary.contains(key) {
                                Text(" must set primary")
                            } else if allMatch.contains(key) {
                                Text(" all match")
                            } else if allEnabledMatch.contains(key) {
                                Text(" all enabled match")
                            }
                            
                            Spacer()
                            
                            if let primary = primary[key] {
                                Text(primary)
                            }
                        }
                        .bold(needsPrimary.contains(key) || (!allMatch.contains(key) && !allEnabledMatch.contains(key)))
                    }
                }
            }
            .navigationDestination(for: ScoreId.self) { scoreId in
                DuplicateScoreListView(document: $document, scoreId: scoreId)
            }
        }
        .task {
            // count of distinct tables by scoreId (nvram + offset)
            counts = Dictionary(
                grouping: document.contents.tables.values
                    .compactMap { $0.scoreId },
                by: \.self
            )
            .mapValues(\.count)
            .filter { $0.value > 1 }

            // tables that can contribute scores
            let primaryTables = document.contents.tables.values
                .filter {
                    !document.contents.hasMisconfiguredScores($0)
                }
                .sorted()
            
            // the primary table (exemplar in consistent order) of a table
            // for a given scoreId
            primary = Dictionary(primaryTables.map { ($0.scoreId, $0.name) }, uniquingKeysWith: { a, b in a })
            
            // the TableScoreboard doesn't have a webId set (doesn't have a game picked)
            needsPrimary = Set(counts.keys.filter { document.contents.scores[$0] == nil })
            
            // there are multiple but all of the tables have the same id (good)
            allMatch = Set(
                counts.keys.filter {
                    Set(document.contents.tablesByScoreId[$0]?.map { $0.webId } ?? []).count == 1
                })
            
            // there are multiple but all of the *enabled* tables have the same id (good)
            allEnabledMatch = Set(
                counts.keys.filter {
                    Set(document.contents.tablesByScoreId[$0]?.filter { !$0.disabled }.map { $0.webId } ?? []).count <= 1
                })
        }
    }
}

struct DuplicateScoreListView: View {

    @Binding var document: ScoreboardDocument
    let scoreId: ScoreId

    var body: some View {
        let tables = (document.contents.tablesByScoreId[scoreId] ?? []).sorted()

        return ScrollView(.vertical) {
            VStack {
                let missingPrimary = document.contents.scores[scoreId]?.webId == nil
                ForEach(tables) { table in
                    HStack {
                        let misconfigured = document.contents.hasMisconfiguredScores(table)
                        Button(action: {
                            document.contents.setScoresWebId(table)
                        }) {
                            Text("\(table.longName ?? table.name)")
                                .bold(!misconfigured)
                        }
                        .disabled(!missingPrimary && !misconfigured)

                        if !misconfigured {
                            Text("Active").bold()
                        }
                        
                        if table.disabled {
                            Text("Disabled")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
