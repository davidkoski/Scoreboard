//
//  Table.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Table : Equatable, Identifiable {
    @Attribute(.unique)
    var id: String
    
    var name: String
    
    var popperId: String?
    
    @Relationship(deleteRule: .cascade)
    var scores: [Score]
    
    @Relationship(inverse: \Tag.tables)
    var tags: [Tag]
    
    internal convenience init(_ entry: PinballDB.Entry) {
        self.init(id: entry.id, name: entry.name)
    }

    internal init(id: String, name: String) {
        self.id = id
        self.name = name
        self.scores = []
        self.tags = []
    }
}

@Model
final class Score {
    var person: String
    var score: Int
    var date: Date
    
    @Relationship(inverse: \Table.scores)
    var table: Table?
    
    internal init(person: String, score: Int, date: Date = Date()) {
        self.person = person
        self.score = score
        self.date = date
    }
}

@Model
final class Tag : Comparable {
    @Attribute(.unique)
    var tag: String
    
    var symbol: String?
    
    var sortOrder: Int
    
    @Relationship
    var tables: [Table]

    internal init(tag: String, symbol: String? = nil, sortOrder: Int = 0, tables: [Table] = []) {
        self.tag = tag
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.tables = tables
    }
    
    static func < (lhs: Tag, rhs: Tag) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

@ViewBuilder
func display(tag: Tag) -> some View {
    if let symbol = tag.symbol, !symbol.isEmpty {
        display(symbol: symbol)
    } else {
        Text(tag.tag)
    }
}


func display(symbol: String?) -> some View {
    Group {
        if let symbol {
            switch symbol.count {
            case 0:
                EmptyView()
            case 1:
                Text(symbol)
            default:
                Image(systemName: symbol)
            }
        }
    }
}
