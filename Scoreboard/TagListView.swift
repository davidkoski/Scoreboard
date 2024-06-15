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

    @Query var tags: [Tag]
    
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
            
            SwiftUI.Table(tags) {
                TableColumn("Tag") { tag in
                    Text(tag.tag)
                }
                TableColumn("Symbol") { tag in
                    display(symbol: tag.symbol)
                }
                
                TableColumn("") { tag in
                    Button(role: .destructive, action: { confirmationShown = true }) {
                        Image(systemName: "trash")
                    }
                    .confirmationDialog(
                        "Are you sure?",
                        isPresented: $confirmationShown
                    ) {
                        Button("Yes") {
                            delete(tag)
                        }
                    }
                }
                .width(min: 30, max: 30)
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
    }
}
