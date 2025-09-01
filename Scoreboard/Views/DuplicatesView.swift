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
    @State var duplicates = [ScoreId: DuplicateTables]()

    var body: some View {
        VStack {
            List {
                let duplicates = duplicates.sorted { $0.key < $1.key }
                ForEach(duplicates, id: \.key) { key, tables in
                    let disposition = tables.disposition
                    NavigationLink(value: key) {
                        Text("\(String(describing: key)) (\(tables.count))")

                        switch disposition {
                        case .allMatch: Text(" all match")
                        case .allEnabledMatch: Text(" all enabled match")
                        case .allDisabled: Text(" all tables disabled")
                        case .needsPrimary: Text(" mismatch, primary set")
                        case .mismatch: Text(" must set primary")
                        }

                        Spacer()

                        if let primary = tables.primaryTable {
                            Text(primary.name)
                        }
                    }
                    .bold(disposition.needsWork)
                }
            }
            .navigationDestination(for: ScoreId.self) { scoreId in
                DuplicateScoreListView(
                    document: $document, scoreId: scoreId,
                    duplicates: DuplicateTables(model: document.contents))
            }
        }

        // update when tables changes
        .task(id: document.serialNumber) {
            duplicates = DuplicateTables.buildDuplicates(from: document.contents)
                .filter { $0.value.count > 1 }
        }
    }
}

struct DuplicateScoreListView: View {

    @Binding var document: ScoreboardDocument
    let scoreId: ScoreId
    @State var duplicates: DuplicateTables

    var body: some View {
        let tables = duplicates.tables.sorted()

        return ScrollView(.vertical) {
            VStack {
                let primaryWebId = duplicates.primaryWebId
                ForEach(tables) { table in
                    HStack {
                        let misconfigured = document.contents.hasMisconfiguredScores(table)
                        let hasZeroOffset = scoreId.offset != 0 && table.scoreId.offset == 0
                        let enabled =
                            (misconfigured || (primaryWebId != table.webId)) && !hasZeroOffset
                        Button(action: {
                            document.contents.setScoresWebId(table)
                        }) {
                            Text("\(table.longName ?? table.name)")
                                .bold(!misconfigured)
                        }
                        .disabled(!enabled)

                        if primaryWebId == table.webId {
                            Text("Primary").bold()
                        }

                        if table.disabled {
                            Text("Disabled")
                        }

                        if hasZeroOffset {
                            Text("Has zero NVOffset")
                        }
                    }
                }
            }
            .task(id: document.contents.scores) {
                duplicates = DuplicateTables.buildDuplicates(
                    from: document.contents, scoreId: scoreId)
            }
            .padding()
        }
    }
}
