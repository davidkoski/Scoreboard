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
    var serialNumber = 0

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
    
    mutating func incrementSerialNumber() {
        serialNumber += 1
    }

    subscript(id: CabinetTableId) -> Table? {
        get {
            contents[id]
        }
        set {
            contents[id] = newValue
            incrementSerialNumber()
        }
    }

    subscript(table: Table) -> Table {
        get {
            contents[table.cabinetId] ?? table
        }
        set {
            contents[table.cabinetId] = newValue
            incrementSerialNumber()
        }
    }
}
