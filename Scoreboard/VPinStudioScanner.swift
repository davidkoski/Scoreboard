//
//  VPinStudioScanner.swift
//  Scoreboard
//
//  Created by David Koski on 8/15/24.
//

import Foundation
import SwiftUI

/// Gathers data from VPin Studio and updates the ````
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
        Button(action: resetScanScores) {
            Text("􀁠")
        }
        .help("Reset table status + rescan")
        Button(action: scanVPinMania) {
            Text("􀚁 Mania")
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
                    if let existing = document.contents[table.cabinetId] {
                        if document[existing].update(table) {
                            messages.append("Update \(existing.longDisplayName)")
                        }
                    } else {
                        // new table
                        let new = Table(table: table)
                        messages.append("New \(new.longDisplayName)")
                        document[new] = new
                    }
                }

                // any tables that no longer appear are deleted and can be marked as disabled
                var tableIds = Set(document.contents.tables.keys)
                for table in tables {
                    tableIds.remove(table.cabinetId)
                }

                for tableId in tableIds {
                    if document[tableId]?.disabled ?? true {
                        // missing or already disabled
                    } else {
                        document[tableId]?.disabled = true
                        if let table = document[tableId] {
                            messages.append("Deleted (disabled) \(table.longDisplayName)")
                        }
                    }
                }

            } catch {
                print("Unable to scanTables: \(error)")
                messages.append("Failed: \(error)")
            }
            busy = false
        }
    }

    private func resetScanScores() {
        for table in document.contents.tables.values {
            if table.scoreStatus != .ok {
                document[table].scoreStatus = nil
            }
        }
        scanScores()
    }

    private func scanScores() {
        let client = VPinStudio()
        Task {
            do {
                let activities = try await client.getActivityDetails()
                document.contents.activity.record(activities, tables: document.contents.tables)
            } catch {
                print("Unable to getActivityDetails: \(error)")
                messages.append("failed: \(error)")
            }
        }
        Task {
            do {
                busy = true
                try await withThrowingTaskGroup(of: (Table, Score?, VPinStudio.ScoreStatus?)?.self)
                { group in
                    current = "Sending requests..."

                    for table in document.contents.tables.values {

                        group.addTask {
                            if table.disabled {
                                // skip -- disabled or deleted
                                return nil
                            }
                            if await document.contents.hasMisconfiguredScores(table) {
                                // table does not
                                return nil
                            }

                            let scores = try await client.getScores(id: table.cabinetId)
                            if let best = bestScore(scores) {
                                return (
                                    table,
                                    .init(
                                        initials: OWNER_INITIALS, score: best.score),
                                    .ok
                                )
                            } else if table.scoreStatus == nil {
                                // no score, we don't know why (yet)
                                let status = try await client.getScoreStatusForEmptyScore(
                                    id: table.cabinetId)
                                return (table, nil, status)
                            }

                            return nil
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

                        if let (table, score, scoreStatus) = pair {
                            if let score {
                                if document.contents[score: table].add(score) {
                                    messages.append("\(table.name): \(score.score)")
                                    document[table].scoreStatus = .ok
                                }
                            } else if let scoreStatus {
                                if scoreStatus != .ok {
                                    messages.append("\(table.name): \(scoreStatus)")
                                }
                                document[table].scoreStatus = scoreStatus
                            }
                        }
                    }
                    document.incrementSerialNumber()
                }
            } catch {
                print("Unable to scanScores: \(error)")
                messages.append("failed: \(error)")
            }
            busy = false
        }
    }

    private func scanVPinMania() {
        Task {
            do {
                busy = true
                let client = VPinStudio()

                // gather scores from vpinmania
                try await withThrowingTaskGroup(of: (ScoreId, [VPinStudio.VPinManiaScore]).self) {
                    group in
                    for (scoreId, scoreboard) in document.contents.scores {
                        group.addTask {
                            (scoreId, try await client.getVPinManiaScores(id: scoreboard.webId))
                        }
                    }

                    let count = document.contents.scores.count
                    var nextUpdate = Date.timeIntervalSinceReferenceDate
                    var i = 0

                    for try await (scoreId, scores) in group {
                        document.contents.scores[scoreId]?.mergeVPinManiaScores(scores)

                        let now = Date.timeIntervalSinceReferenceDate
                        if now >= nextUpdate {
                            current = "\(i)/\(count)"
                            nextUpdate = now + 0.25
                        }

                        i += 1
                    }
                }

                let count = document.contents.scores.count
                var nextUpdate = Date.timeIntervalSinceReferenceDate
                for (i, (scoreId, scoreboard)) in document.contents.scores.enumerated() {
                    let scores = try await client.getVPinManiaScores(id: scoreboard.webId)
                    document.contents.scores[scoreId]?.mergeVPinManiaScores(scores)

                    let now = Date.timeIntervalSinceReferenceDate
                    if now >= nextUpdate {
                        current = "\(i)/\(count)"
                        nextUpdate = now + 0.25
                    }
                }
                
                document.incrementSerialNumber()

            } catch {
                print("Unable to scanScores: \(error)")
                messages.append("failed: \(error)")
            }
            busy = false
        }
    }
}
