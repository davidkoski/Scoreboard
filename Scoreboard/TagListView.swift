//
//  TagListView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI

struct TagListView : View {
    
    @Binding var document: ScoreboardDocument

    @State private var confirmationShown = false

    @State private var tag = ""
    @State private var symbol = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("Tag", text: $tag)
                TextField("Symbol", text: $symbol)
                    .onSubmit {
                        save()
                    }
                
                display(symbol: symbol)
                    .frame(width: 40)
                
                Button(action: save) {
                    Text("Save")
                }
            }
            .padding(3)
                        
            List {
                ForEach(document.contents.tags) { tag in
                    HStack {
                        NavigationLink(value: tag) {
                            display(symbol: tag.symbol)
                                .frame(maxWidth: 40)
                            Text(tag.tag)
                        }                        
                    }
                }
                .onDelete(perform: { indexes in
                    deleteTags(
                        document.contents.tags
                            .enumerated()
                            .filter {
                                indexes.contains($0.0)
                            }
                            .map { $0.1 }
                        )
                })
                .onMove { indexes, position in
                    document.contents.tags.move(fromOffsets: indexes, toOffset: position)
                }
            }
        }
    }
    
    @MainActor
    private func deleteTags(_ tags: [Tag]) {
        document.contents.tags.removeAll { tag in
            tags.contains(tag)
        }
        
        let delete = tags.map { $0.tag }
        document.contents.tables = document.contents.tables.mapValues { table in
            if !table.tags.isDisjoint(with: delete) {
                var table = table
                table.tags.subtract(delete)
                return table
            } else {
                return table
            }
        }
    }
        
    @MainActor
    private func save() {
        let tag = Tag(tag: tag, symbol: symbol.isEmpty ? nil : symbol)
        document.contents.tags.append(tag)
        
        self.tag = ""
        self.symbol = ""
    }
}
