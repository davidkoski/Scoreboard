//
//  Table.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftUI

struct ScoreModel: Codable {
    var tableInfo = [WebTableId: TableInfo]()
    var scores = [ScoreId: TableScoreboard]()
    private(set) var tables = [CabinetTableId: Table]()

    private(set) var tablesByWebId = [WebTableId: [Table]]()
    private(set) var tablesByScoreId = [ScoreId: [Table]]()

    init() {
    }

    private enum CodingKeys: CodingKey {
        case tableInfo
        case scores
        case tables
    }

    func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<ScoreModel.CodingKeys> = encoder.container(
            keyedBy: ScoreModel.CodingKeys.self)

        try container.encode(self.tableInfo, forKey: ScoreModel.CodingKeys.tableInfo)
        try container.encode(self.scores, forKey: ScoreModel.CodingKeys.scores)
        try container.encode(self.tables, forKey: ScoreModel.CodingKeys.tables)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.tableInfo = try container.decode([WebTableId: TableInfo].self, forKey: .tableInfo)
        self.scores = try container.decode([ScoreId: TableScoreboard].self, forKey: .scores)
        self.tables = try container.decode([CabinetTableId: Table].self, forKey: .tables)

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
        scores[table.scoreId]?.webId != table.webId
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
        if let old, let new {
            if old.scoreId != new.scoreId && old.scoreId.isManual {
                // changing the scoreId and the old one was manual -- move it to the new
                // scoreId
                if var scoreboard = scores[old.scoreId] {
                    scoreboard.webId = new.webId
                    scores[new.scoreId] = scoreboard
                    scores.removeValue(forKey: old.scoreId)
                }
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

    var id: Date { date }

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
struct TableScoreboard: Codable {
    var webId: WebTableId
    private(set) var entries = [Score]()

    init(_ table: Table) {
        self.webId = table.webId
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

    /// table is disabled in the cabinet
    var disabled: Bool

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

        return changed
    }

    static func < (lhs: Table, rhs: Table) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
