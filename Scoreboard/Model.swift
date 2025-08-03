//
//  Table.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftUI

/// Table to be displayed in the UI
struct TableItem: Identifiable, Equatable {
    let table: Table
    let scoreCount: Int
    let score: Int
    let rank: Int
    let rankCount: Int
    let lastScoreDate: Date?
    var lastScoreDateComparable: TimeInterval { lastScoreDate?.timeIntervalSinceReferenceDate ?? 0 }

    var id: CabinetTableId { table.id }

    init(table: Table, document: ScoreboardDocument) {
        self.table = table
        let scoreboard = document.contents[table.scoreId]
        self.scoreCount = scoreboard?.localCount ?? 0
        self.score = scoreboard?.best()?.score ?? 0
        self.rank = scoreboard?.rank() ?? 0
        self.rankCount = scoreboard?.rankCount() ?? 0
        self.lastScoreDate = scoreboard?.best()?.date
    }
}

struct ScoreModel: Codable {
    var tableInfo = [WebTableId: TableInfo]()
    var scores = [ScoreId: TableScoreboard]()
    var activity: Activity

    private(set) var tables = [CabinetTableId: Table]()

    private(set) var tablesByWebId = [WebTableId: [Table]]()
    private(set) var tablesByScoreId = [ScoreId: [Table]]()

    init() {
        self.activity = .init()
    }

    private enum CodingKeys: CodingKey {
        case tableInfo
        case scores
        case tables
        case activity
    }

    func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<ScoreModel.CodingKeys> = encoder.container(
            keyedBy: ScoreModel.CodingKeys.self)

        try container.encode(self.tableInfo, forKey: ScoreModel.CodingKeys.tableInfo)
        try container.encode(self.scores, forKey: ScoreModel.CodingKeys.scores)
        try container.encode(self.tables, forKey: ScoreModel.CodingKeys.tables)
        try container.encode(self.activity, forKey: ScoreModel.CodingKeys.activity)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.tableInfo = try container.decode([WebTableId: TableInfo].self, forKey: .tableInfo)
        self.scores = try container.decode([ScoreId: TableScoreboard].self, forKey: .scores)
        self.tables = try container.decode([CabinetTableId: Table].self, forKey: .tables)
        self.activity = try container.decodeIfPresent(Activity.self, forKey: .activity) ?? .init()

        // build in-memory index
        for table in tables.values {
            tablesByWebId[table.webId, default: []].append(table)
            tablesByScoreId[table.scoreId, default: []].append(table)
        }
    }

    public subscript(key: CabinetTableId) -> Table? {
        get { tables[key] }
        set {
            updateIndex(old: tables[key], new: newValue)
            tables[key] = newValue
        }
    }

    public subscript(key: ScoreId) -> TableScoreboard? {
        get { scores[key] }
        set { scores[key] = newValue }
    }

    public subscript(score table: Table) -> TableScoreboard {
        get { scores[table.scoreId, default: .init(table)] }
        set { scores[table.scoreId] = newValue }
    }

    public func hasMisconfiguredScores(_ table: Table) -> Bool {
        if let scores = scores[table.scoreId] {
            scores.webId != table.webId
        } else {
            false
        }
    }

    public mutating func setScoresWebId(_ table: Table) {
        self[score: table].webId = table.webId
    }

    public func representative(_ scoreId: ScoreId) -> Table? {
        if let scores = scores[scoreId] {
            let webId = scores.webId
            if let table = tablesByScoreId[scoreId]?.lazy.first(where: {
                !$0.disabled && $0.webId == webId
            }) {
                return table
            }
            if let table = tablesByScoreId[scoreId]?.lazy.first(where: { $0.webId == webId }) {
                return table
            }
        }

        // we don't know which webId goes with it so just return one of them
        if let table = tablesByScoreId[scoreId]?.lazy.first(where: { !$0.disabled }) {
            return table
        }
        return tablesByScoreId[scoreId]?.first
    }

    private mutating func updateIndex(old: Table?, new: Table?) {
        if old?.webId != new?.webId {
            if let webId = old?.webId, let id = old?.id {
                tablesByWebId[webId]?.removeAll(where: { $0.id == id })
                if tablesByWebId[webId]?.isEmpty == true {
                    tablesByWebId.removeValue(forKey: webId)
                }
            }
            if let new {
                tablesByWebId[new.webId, default: []].append(new)
            }
        }
        if old?.scoreId != new?.scoreId {
            if let scoreId = old?.scoreId, let id = old?.id {
                tablesByScoreId[scoreId]?.removeAll(where: { $0.id == id })
                if tablesByScoreId[scoreId]?.isEmpty == true {
                    tablesByScoreId.removeValue(forKey: scoreId)
                }
            }
            if let new {
                tablesByScoreId[new.scoreId, default: []].append(new)
            }
        }
        if let old, let new, old.scoreId != new.scoreId {

            func move() {
                if var scoreboard = scores[old.scoreId] {
                    scoreboard.webId = new.webId
                    scores[new.scoreId] = scoreboard
                    scores.removeValue(forKey: old.scoreId)
                }
            }

            if old.scoreId.isManual {
                // changing the scoreId and the old one was manual -- move it to the new scoreId
                move()
            } else if let scores = scores[old.scoreId], scores.webId == old.webId {
                // the scoreId changed (maybe the offset changed) and the scores
                // match the webId (overall table) of the item that is moving
                // so move the scores too
                move()
            }
        }
    }
}

struct TableInfo: Codable {
    let name: String
}

/// A single score entry
struct Score: Identifiable, Comparable, Hashable, Codable {
    var initials: String
    var score: Int
    var date = Date()

    var id: String { "\(initials)\(score)" }

    var isLocal: Bool { initials == OWNER_INITIALS }

    static func < (lhs: Score, rhs: Score) -> Bool {
        lhs.score > rhs.score
    }

    static func == (lhs: Score, rhs: Score) -> Bool {
        lhs.initials == rhs.initials && lhs.score == rhs.score
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(initials)
        hasher.combine(score)
    }
}

/// A scoreboard for a table
struct TableScoreboard: Codable, Equatable {
    var webId: WebTableId

    /// maybe useful if I update a table with an nvoffset and need to figure out what the old offset was
    var name: String
    private(set) var entries = [Score]()

    init(_ table: Table) {
        self.webId = table.webId
        self.name = table.name
    }

    public var localCount: Int { entries.lazy.filter { $0.isLocal }.count }

    public func rank(initials: String = OWNER_INITIALS) -> Int? {
        if let index = entries.firstIndex(where: { $0.initials == initials }) {
            index + 1
        } else {
            nil
        }
    }

    public func rankCount(initials: String = OWNER_INITIALS) -> Int {
        entries
            .lazy
            .filter { $0.initials != initials }
            .count + 1
    }

    public func best(initials: String = OWNER_INITIALS) -> Score? {
        entries.first { $0.initials == initials }
    }

    @discardableResult
    public mutating func add(_ score: Score) -> Bool {
        guard !entries.contains(score) else { return false }

        entries.append(score)
        entries.sort()
        return true
    }

    public mutating func remove(_ score: Score) {
        entries.removeAll { $0 == score }
    }

    public mutating func mergeVPinManiaScores(_ scores: [VPinStudio.VPinManiaScore]) {
        // note: the vpin mania scores often contain dups, thus the Set
        entries =
            entries.filter { $0.isLocal } + Set(scores).map { $0.asScore() }.filter { !$0.isLocal }
        entries.sort()
    }
}

private func vrType(_ table: VPinStudio.TableDetails) -> Table.VR {
    let name = table.gameDisplayName ?? ""
    if name.hasSuffix("VR") {
        return .full
    } else if name.hasSuffix("VROK") {
        return .partial
    } else {
        return .flat
    }
}

struct Table: Identifiable, Comparable, Hashable, Codable {
    var id: CabinetTableId { cabinetId }

    /// unique identifier for table, e.g. sMBqx5fp.  This is the identifier from the ``PinballDB``
    var webId: WebTableId

    /// short name, e.g. 2001 (Gottlieb 1971)
    var name: String

    /// long name, e.g. 2001 (Gottlieb 1971) Wrd1972 0.99a
    var longName: String?

    var longDisplayName: String { longName ?? name }

    /// numeric identifier (row id) for cabinet database
    var cabinetId: CabinetTableId

    var scoreId: ScoreId

    var scoreType: VPinStudio.HighScoreType?
    var scoreStatus: VPinStudio.ScoreStatus?

    var comparableScoreStatus: VPinStudio.ScoreStatus { scoreStatus ?? .unknown }
    var comparableScoreType: VPinStudio.HighScoreType { scoreType ?? .na }

    /// table is disabled in the cabinet
    var disabled: Bool

    enum VR: Codable, CaseIterable {
        case full
        case partial
        case flat

        func matches(_ other: VR) -> Bool {
            switch (self, other) {
            case (.full, .full): return true
            case (.full, .partial): return true
            case (.partial, .partial): return true
            case (_, .flat): return true
            default: return false
            }
        }

        var imageName: String {
            switch self {
            case .flat: "rectangle"
            case .partial: "cube.transparent"
            case .full: "cube"
            }
        }
    }

    var vr: VR

    var sortKey: String {
        name
            .lowercased()
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "jp's ", with: "")
    }

    init(table: VPinStudio.TableDetails) {
        self.webId = table.webId
        self.name = table.gameName
        self.longName = table.gameDisplayName
        self.cabinetId = table.cabinetId
        self.scoreType = table.highscoreType
        self.scoreId = table.scoreId
        self.disabled = table.disabled
        self.vr = vrType(table)
    }

    public mutating func update(_ other: VPinStudio.TableDetails) -> Bool {
        var changed = false

        func update<V: Equatable>(
            _ keypath: WritableKeyPath<Table, V>,
            _ otherKeypath: KeyPath<VPinStudio.TableDetails, V>
        ) {
            if self[keyPath: keypath] != other[keyPath: otherKeypath] {
                changed = true
                self[keyPath: keypath] = other[keyPath: otherKeypath]
            }
        }

        update(\.name, \.gameName)
        update(\.longName, \.gameDisplayName)
        update(\.webId, \.webId)
        update(\.disabled, \.disabled)

        update(\.scoreType, \.highscoreType)
        update(\.scoreId, \.scoreId)

        let vr = vrType(other)
        if self.vr != vr {
            changed = true
            self.vr = vr
        }

        return changed
    }

    static func < (lhs: Table, rhs: Table) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}

/// Record of tables played by day
struct Activity: Codable {

    static func dateCode(_ date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return year * 100 * 100 + month * 100 + day
    }

    static func dateFromCode(_ code: Int) -> Date {
        DateComponents(year: code / 10000, month: (code % 10000) / 100, day: code % 100).date!
    }

    struct Snapshot: Codable, Equatable {
        var lastPlayed: Int
        var numberOfPlays: Int
        var timePlayedSecs: Int

        init(_ activity: VPinStudio.Activity) {
            self.lastPlayed = dateCode(activity.lastPlayed)
            self.numberOfPlays = activity.numberOfPlays
            self.timePlayedSecs = activity.timePlayedSecs
        }
    }

    struct Play: Codable, Equatable, Comparable {
        var timePlayedSecs = 0

        mutating func record(seconds: Int) {
            timePlayedSecs += seconds
        }

        static func < (lhs: Activity.Play, rhs: Activity.Play) -> Bool {
            lhs.timePlayedSecs < rhs.timePlayedSecs
        }
    }

    struct DayRecord: Codable, Equatable, Comparable {
        var dateCode: Int
        var tablesPlayed: Int
        var secondsPlayed: Int
        var plays: [WebTableId: Play]

        init(_ snapshot: Snapshot) {
            self.dateCode = snapshot.lastPlayed
            self.tablesPlayed = 0
            self.secondsPlayed = 0
            self.plays = [:]
        }

        mutating func record(tableId: WebTableId, snapshot: Snapshot, current: Snapshot?) {
            let seconds = snapshot.timePlayedSecs - (current?.timePlayedSecs ?? 0)
            plays[tableId, default: .init()].record(seconds: seconds)
            self.tablesPlayed = plays.count
            self.secondsPlayed = plays.values.map { $0.timePlayedSecs }.reduce(0, +)
        }

        static func < (lhs: Activity.DayRecord, rhs: Activity.DayRecord) -> Bool {
            lhs.dateCode < rhs.dateCode
        }
    }

    var snapshots = [CabinetTableId: Snapshot]()
    var days = [DayRecord]()

    mutating func record(_ activities: [VPinStudio.Activity], tables: [CabinetTableId: Table]) {
        guard !snapshots.isEmpty else {
            // initial fill
            for activity in activities {
                let snapshot = Snapshot(activity)
                snapshots[activity.gameId] = snapshot
            }
            return
        }

        if !snapshots.isEmpty {
            var changed = false
            var days = Dictionary(uniqueKeysWithValues: days.map { ($0.dateCode, $0) })
            for activity in activities {
                guard let table = tables[activity.gameId] else { continue }
                let snapshot = Snapshot(activity)
                let current = snapshots[activity.gameId]
                self.snapshots[activity.gameId] = snapshot

                var recordSnapshot = false
                if let current {
                    if current != snapshot {
                        // activity
                        recordSnapshot = true
                    }
                } else {
                    // new record
                    recordSnapshot = true
                }

                if recordSnapshot {
                    changed = true
                    days[snapshot.lastPlayed, default: .init(snapshot)]
                        .record(tableId: table.webId, snapshot: snapshot, current: current)
                }
            }

            if changed {
                self.days = days.values.sorted()
            }
        }
    }
}
