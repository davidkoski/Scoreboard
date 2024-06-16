//
//  TagListView.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI
import SwiftData

struct TagListView : View {
    
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Tag.sortOrder)]) var tags: [Tag]
    
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
                ForEach(tags, id: \.tag) { tag in
                    HStack {
                        NavigationLink(value: tag) {
                            display(symbol: tag.symbol)
                                .frame(maxWidth: 40)
                            Text(tag.tag)
                        }                        
                    }
                }
                .onDelete(perform: { indexes in
                    tags
                        .enumerated()
                        .filter {
                            indexes.contains($0.0)
                        }
                        .forEach { (_, tag) in
                            modelContext.delete(tag)
                        }
                    try! modelContext.save()
                })
                .onMove { indexes, position in
                    var tags = self.tags
                    tags.move(fromOffsets: indexes, toOffset: position)
                    for (index, tag) in tags.enumerated() {
                        tag.sortOrder = index
                    }
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func delete(_ tag: Tag) {
        modelContext.delete(tag)
        try! modelContext.save()
    }
    
    private func save() {
        let tag = Tag(tag: tag, symbol: symbol.isEmpty ? nil : symbol)
        modelContext.insert(tag)
        try! modelContext.save()
        
        self.tag = ""
        self.symbol = ""
    }
}
