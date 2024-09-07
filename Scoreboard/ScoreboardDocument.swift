//
//  ScoreboardDocument.swift
//  Scoreboard
//
//  Created by David Koski on 6/16/24.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum ScoreboardDocumentError : Error {
    case noData
}

struct ScoreboardDocument : FileDocument {
    
    static let readableContentTypes = [UTType(importedAs: "com.koski.scoreboards")]
    
    var contents: Scoreboard

    init() {
        contents = Scoreboard()
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.contents = try JSONDecoder().decode(Scoreboard.self, from: data)
        } else {
            throw ScoreboardDocumentError.noData
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: try JSONEncoder().encode(contents))
    }

    subscript(id: String) -> Table? {
        get {
            contents.tables[id]
        }
        set {
            contents.tables[id] = newValue
        }
    }

    subscript(table: Table) -> Table {
        get {
            contents.tables[table.id] ?? table
        }
        set {
            contents.tables[table.id] = newValue
        }
    }
    
    func isPrimaryForHighScore(_ table: Table) -> Bool {
        if let key = table.highScoreKey {
            contents.primaryForHighScoreKey[key] == table.id
        } else {
            true
        }
    }
    
    func primaryForHighScore(_ table: Table) -> Table? {
        if let key = table.highScoreKey {
            if let id = contents.primaryForHighScoreKey[key] {
                contents.tables[id]
            } else {
                nil
            }
        } else {
            table
        }
    }
    
    func hasPrimaryForHighScore(_ table: Table) -> Bool {
        if let key = table.highScoreKey {
            contents.primaryForHighScoreKey[key] != nil
        } else {
            true
        }
    }
    
    func hasPrimaryForHighScore(_ key: String) -> Bool {
        contents.primaryForHighScoreKey[key] != nil
    }

    mutating func setIsPrimaryForHighScore(_ table: Table) {
        if let key = table.highScoreKey {
            contents.primaryForHighScoreKey[key] = table.id
        }
    }
}

