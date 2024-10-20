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

    var body: some View {
        VStack {
            List {
                let counts = counts.sorted { $0.key < $1.key }
                ForEach(counts, id: \.key) { key, count in
                    NavigationLink(value: key) {
                        Text("\(key) (\(count))")
                            .bold(needsPrimary.contains(key))

                        if allMatch.contains(key) {
                            Text(" all match")
                        }
                    }
                }
            }
            .navigationDestination(for: ScoreId.self) { scoreId in
                DuplicateScoreListView(document: $document, scoreId: scoreId)
            }
        }
        .task {
            counts = Dictionary(
                grouping: document.contents.tables.values
                    .compactMap { $0.scoreId },
                by: \.self
            )
            .mapValues(\.count)
            .filter { $0.value > 1 }

            needsPrimary = Set(counts.keys.filter { document.contents.scores[$0] == nil })
            allMatch = Set(
                counts.keys.filter {
                    Set(document.contents.tablesByScoreId[$0]?.map { $0.webId } ?? []).count == 1
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
                ForEach(tables) { table in
                    HStack {
                        let misconfigured = document.contents.hasMisconfiguredScores(table)
                        Button(action: {
                            document.contents.setScoresWebId(table)
                        }) {
                            Text("\(table.longName ?? table.name)")
                                .bold(!misconfigured)
                        }
                        .disabled(!misconfigured)

                        if !misconfigured {
                            Text("Active").bold()
                        }
                    }
                }
            }
            .padding()
        }
    }
}
