//
//  ScoreboardDocument.swift
//  Scoreboard
//
//  Created by David Koski on 6/16/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ScoreboardDocumentError: Error {
    case noData
}

struct ScoreboardDocument: FileDocument {

    static let readableContentTypes = [UTType(importedAs: "com.koski.scoreboards")]

    var contents: ScoreModel

    init() {
        contents = ScoreModel()
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.contents = try JSONDecoder().decode(ScoreModel.self, from: data)
        } else {
            throw ScoreboardDocumentError.noData
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: try JSONEncoder().encode(contents))
    }

    subscript(id: CabinetTableId) -> Table? {
        get {
            contents[id]
        }
        set {
            contents[id] = newValue
        }
    }

    subscript(table: Table) -> Table {
        get {
            contents[table.cabinetId] ?? table
        }
        set {
            contents[table.cabinetId] = newValue
        }
    }
}
