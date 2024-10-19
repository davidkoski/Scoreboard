//
//  Table.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftUI

struct Scoreboard: Codable {
    var tables = [String: Table]()
    var primaryForHighScoreKey = [String: String]()

    init() {
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tables = try container.decode([String: Table].self, forKey: .tables)
        self.primaryForHighScoreKey =
            try container.decodeIfPresent([String: String].self, forKey: .primaryForHighScoreKey)
            ?? [:]
    }
}

struct Score: Identifiable, Comparable, Hashable, Codable {
    var initials: String
    var score: Int
    var date = Date()

    var id: Date { date }

    static func < (lhs: Score, rhs: Score) -> Bool {
        lhs.score > rhs.score
    }
}

struct Table: Identifiable, Comparable, Hashable, Codable {
    var id: String
    var name: String
    var popperId: String
    var scoreType: String?
    var scoreStatus: VPinStudio.ScoreStatus?
    var scores = [Score]()

    /// scores are saved under this key -- some other tables may also use this key, beware!
    var highScoreKey: String?

    var sortKey: String {
        name
            .lowercased()
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "jp's ", with: "")
    }

    init(table: VPinStudio.TableDetails) {
        self.id = table.id
        self.name = table.gameName
        self.popperId = table.popperId
        if table.isNVRam {
            self.highScoreKey = table.rom
        }
        self.scoreType = table.highscoreType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.popperId = try container.decodeIfPresent(String.self, forKey: .popperId) ?? ""
        if self.popperId == "" {
            print(name)
        }
        self.scores = try container.decode([Score].self, forKey: .scores)
        self.scoreType = try container.decodeIfPresent(String.self, forKey: .scoreType)
        self.scoreStatus = try container.decodeIfPresent(
            VPinStudio.ScoreStatus.self, forKey: .scoreStatus)
        self.highScoreKey = try container.decodeIfPresent(String.self, forKey: .highScoreKey)
    }

    static func < (lhs: Table, rhs: Table) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}
