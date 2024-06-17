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
}

