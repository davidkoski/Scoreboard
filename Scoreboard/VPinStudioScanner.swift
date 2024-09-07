//
//  VPinStudioScanner.swift
//  Scoreboard
//
//  Created by David Koski on 8/15/24.
//

import Foundation
import SwiftUI

struct VPinStudioScanner: View {

    @Binding var document: ScoreboardDocument

    @Binding var busy: Bool
    @Binding var current: String?
    @Binding var messages: [String]

    var body: some View {
        Button(action: scanTables) {
            Text("􀚁 Tables")
        }
        Button(action: scanScores) {
            Text("􀚁 Scores")
        }
    }

    private func scanTables() {
        Task {
            do {
                busy = true
                current = "Fetching tables..."
                let tables = try await VPinStudio().getTablesList()
                current = "Merging tables..."
                for table in tables {
                    if let existing = document.contents.tables[table.id] {
                        // existing, see if it needs updating
                        if existing.name != table.gameName || existing.popperId == "" {
                            messages.append("Rename \(existing.name) -> \(table.gameName)")
                            document[existing].name = table.gameName
                            document[existing].popperId = table.popperId
                        }

                        // if we didn't pick up the rom name do so now
                        if existing.highScoreKey == nil && table.isNVRam {
                            document[existing].highScoreKey = table.rom
                        }
                    } else {
                        // new table
                        messages.append("New \(table.gameName)")
                        let new = Table(table: table)
                        document[new] = new
                    }
                }

                // count how many have each distinct high score type
                let tablesByHighScoreKey = Dictionary(
                    grouping: document.contents.tables.values
                        .filter { $0.highScoreKey != nil },
                    by: { $0.highScoreKey! }
                )
                .filter { $0.value.count == 1 }

                // and mark anything primary that we can
                for (_, tables) in tablesByHighScoreKey {
                    document.setIsPrimaryForHighScore(tables[0])
                }

            } catch {
                print("Unable to scanTables: \(error)")
            }
            busy = false
        }
    }

    private func scanScores() {
        Task {
            do {
                busy = true
                let client = VPinStudio()
                try await withThrowingTaskGroup(of: (Table, Score)?.self) { group in
                    current = "Sending requests..."

                    for table in document.contents.tables.values {
                        let id = table.popperId
                        if document.isPrimaryForHighScore(table) {
                            group.addTask {
                                let scores = try await client.getScores(id: id)
                                if let best = bestScore(scores) {
                                    // skip duplicates
                                    if !table.scores.contains(where: {
                                        $0.score == best.numericScore
                                    }) {
                                        return (
                                            table,
                                            .init(
                                                initials: OWNER_INITIALS, score: best.numericScore)
                                        )
                                    }
                                }

                                return nil
                            }
                        }
                    }

                    // now merge the scores in to the document
                    let count = document.contents.tables.count
                    var i = 0

                    var nextUpdate = Date.timeIntervalSinceReferenceDate

                    for try await pair in group {
                        i += 1

                        let now = Date.timeIntervalSinceReferenceDate
                        if now >= nextUpdate {
                            current = "\(i)/\(count)"
                            nextUpdate = now + 0.25
                        }

                        if let (table, score) = pair {
                            messages.append("\(table.name): \(score.score)")
                            document[table].scores.append(score)
                            document[table].scores.sort()
                        }
                    }
                }
            } catch {
                print("Unable to scanScores: \(error)")
            }
            busy = false
        }
    }

}
