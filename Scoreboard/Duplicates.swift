//
//  Duplicates.swift
//  Scoreboard
//
//  Created by David Koski on 11/16/24.
//

import Foundation

public enum DuplicateDisposition {
    /// all tables in the set match their WebId (the same table)
    case allMatch

    /// all enabled tables in the set match their WebId (disabled tables may vary)
    case allEnabledMatch

    /// all tables are disabled
    case allDisabled

    /// not all tables match and a primary must be chosen
    case needsPrimary

    /// not all tables match (but there is a primary)
    case mismatch

    var needsWork: Bool {
        switch self {
        case .allMatch: false
        case .allEnabledMatch: false
        case .allDisabled: false
        case .needsPrimary: true
        case .mismatch: true
        }
    }
}

public struct DuplicateTables {

    let model: ScoreModel
    var tables = [Table]()

    var count: Int { tables.count }

    var primaryTable: Table? {
        tables.first {
            !model.hasMisconfiguredScores($0)
        }
    }

    var primaryWebId: WebTableId? {
        primaryTable?.webId
    }

    var disposition: DuplicateDisposition {
        let webIds = Set(tables.map { $0.webId })
        if webIds.count == 1 {
            return .allMatch
        }

        let enabledWebIds = Set(tables.filter { !$0.disabled }.map { $0.webId })
        if enabledWebIds.count == 1 {
            return .allEnabledMatch
        } else if enabledWebIds.count == 0 {
            return .allDisabled
        }

        if primaryTable == nil {
            return .mismatch
        } else {
            return .needsPrimary
        }
    }

    mutating func append(_ table: Table) {
        tables.append(table)
    }

    static func buildDuplicates(from model: ScoreModel) -> [ScoreId: DuplicateTables] {
        var scoreIdsByName = [String: Set<ScoreId>]()

        // first add all the tables that have an nvoffset.  tables with an nvoffset
        // of zero match _all_ the nvoffsets (rules of how that works)
        for table in model.tables.values where table.scoreId.offset > 0 {
            scoreIdsByName[table.scoreId.name, default: []].insert(table.scoreId)
        }

        var result = [ScoreId: DuplicateTables]()

        for table in model.tables.values {
            if table.scoreId.offset == 0 {
                result[table.scoreId, default: .init(model: model)].append(table)
                for scoreId in scoreIdsByName[table.scoreId.name] ?? [] {
                    result[scoreId, default: .init(model: model)].append(table)
                }
            } else {
                result[table.scoreId, default: .init(model: model)].append(table)
            }
        }

        return result
    }

    static func buildDuplicates(from model: ScoreModel, scoreId: ScoreId) -> DuplicateTables {
        let tables: [Table]
        if scoreId.offset != 0 {
            // consider tables that do not have NVOffset set
            tables =
                (model.tablesByScoreId[scoreId] ?? [])
                + (model.tablesByScoreId[scoreId.withOffset(0)] ?? [])
        } else {
            tables = model.tablesByScoreId[scoreId] ?? []
        }

        return DuplicateTables(model: model, tables: tables)
    }
}
