//
//  NVRamView.swift
//  Scoreboard
//
//  Created by David Koski on 8/15/24.
//

import Foundation
import SwiftUI

/// we need this wrapper so we have a distinct type for the navigationDestination
struct NVRam: Hashable, Identifiable, Comparable {
    let key: String
    
    var id: String { key }
    
    init?(_ key: String?) {
        if let key {
            self.key = key
        } else {
            return nil
        }
    }
    
    static func < (lhs: NVRam, rhs: NVRam) -> Bool {
        lhs.key < rhs.key
    }
}

struct NVRamView : View {
    
    @Binding var document: ScoreboardDocument
    
    @State var counts: [NVRam: Int] = [:]
    @State var needsPrimary: Set<NVRam> = []

    var body: some View {
        VStack {
            List {
                let counts = counts.sorted { $0.key < $1.key }
                ForEach(counts, id: \.key) { key, count in
                    NavigationLink(value: key) {
                        Text("\(key.key) (\(count))")
                            .bold(needsPrimary.contains(key))
                    }
                }
            }
            .navigationDestination(for: NVRam.self) { nvram in
                NVRamListView(document: $document, highScoreKey: nvram.key)
            }
        }
        .task {
            counts = Dictionary(
                grouping: document.contents.tables.values
                    .compactMap { NVRam($0.highScoreKey) },
                by: \.self)
                .mapValues(\.count)
                .filter { $0.value > 1 }
            
            needsPrimary = Set(counts.keys
                .filter { !document.hasPrimaryForHighScore($0.key) })
        }
    }
}

struct NVRamListView : View {
    
    @Binding var document: ScoreboardDocument
    let highScoreKey: String

    var body: some View {
        let tables = document.contents.tables.values
            .filter { $0.highScoreKey == highScoreKey }
            .sorted()
        
        return ScrollView(.vertical) {
            VStack {
                ForEach(tables) { table in
                    Button(action: {
                        document.setIsPrimaryForHighScore(table)
                    }) {
                        Text("\(table.name)")
                            .bold(document.isPrimaryForHighScore(table))
                    }
                }
            }
        }
    }
}

