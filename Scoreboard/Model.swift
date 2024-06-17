//
//  Table.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftUI

struct Scoreboard : Codable {
    var tables = [String:Table]()
    var tags = [Tag]()
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

struct Table : Identifiable, Comparable, Hashable, Codable {
    var id: String
    var name: String
    var popperId: String?
    var scores = [Score]()
    var tags = Set<String>()
    
    var sortKey: String {
        name
            .lowercased()
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "jp's ", with: "")
    }
    
    static func < (lhs: Table, rhs: Table) -> Bool {
        lhs.sortKey < rhs.sortKey
    }
}

struct Tag : Identifiable, Hashable, Codable {
    var tag: String
    var symbol: String?
    
    var id: String { tag }
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
