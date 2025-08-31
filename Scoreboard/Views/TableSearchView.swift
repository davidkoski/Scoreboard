//
//  ContentView.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import SwiftUI

struct TableListView: View {

    let document: ScoreboardDocument
    @Binding var items: [TableItem]
    var showLastScoreDate = false

    @State var playable = true
    @State var vr: Table.VR = .partial

    @State private var sortOrder = [KeyPathComparator(\TableItem.table.name)]

    func filteredItems() -> [TableItem] {
        items
            .filter {
                !playable || !$0.table.disabled
            }
            .filter {
                $0.table.vr.matches(vr)
            }
    }

    var body: some View {
        SwiftUI.Table(filteredItems(), sortOrder: $sortOrder) {
            TableColumn("Table", value: \.table.name) { item in
                let table = item.table
                NavigationLink(value: table) {
                    Image(systemName: table.vr.imageName)
                    Spacer().frame(width: 4)
                    Text(table.name).italic(table.disabled)
                }
            }
            .width(min: 230)

            TableColumn("Status", value: \.table.comparableScoreStatus) { item in
                let table = item.table
                if table.disabled {
                    Text("disabled").italic()
                } else {
                    Text(table.scoreStatus?.rawValue ?? "-")
                }
            }
            TableColumn("Type", value: \.table.comparableScoreType) { item in
                let table = item.table
                Text(table.scoreType?.rawValue ?? "-")
            }
            TableColumn("Score", value: \.score) { item in
                if item.score == 0 {
                    Text("-")
                } else {
                    Text(item.score.formatted())
                }
            }
            TableColumn("Rank", value: \.rank) { item in
                if item.rank == 0 {
                    if item.rankCount > 0 {
                        Text("- / \(item.rankCount.formatted())")
                    } else {
                        Text("-")
                    }
                } else {
                    Text("\(item.rank.formatted()) / \(item.rankCount.formatted())")
                }
            }
            .width(60)

            TableColumn("Count", value: \.scoreCount) { item in
                if item.scoreCount == 0 {
                    Text("-")
                } else {
                    Text(item.scoreCount.formatted())
                }
            }
            .width(60)

            if showLastScoreDate {
                TableColumn("Last Score", value: \.lastScoreDateComparable) { item in
                    if let lastScoreDate = item.lastScoreDate {
                        Text(lastScoreDate.formatted(date: .numeric, time: .omitted))
                    } else {
                        Text("-")
                    }
                }
            }
        }
        .onChange(of: sortOrder) {
            items.sort(using: sortOrder)
        }
        .toolbar {
            Toggle(isOn: $playable) {
                Image(systemName: "hand.thumbsup")
            }
            .help("show only playable games")
            Button(action: nextVR) {
                Image(systemName: vr.imageName)
            }
            .help("cycle through types of VR games")
        }
        .task {
            if showLastScoreDate {
                sortOrder = [KeyPathComparator(\TableItem.lastScoreDateComparable, order: .reverse)]
            }
        }
    }

    func nextVR() {
        self.vr =
            switch vr {
            case .partial: .full
            case .full: .flat
            case .flat: .partial
            }
    }
}

struct TableSearchView: View {

    let document: ScoreboardDocument

    @Binding var path: NavigationPath
    @Binding var search: String

    @Binding var items: [TableItem]

    var body: some View {
        VStack {
            TableListView(document: document, items: $items)
        }
        .toolbar {
            Button(action: showInCabinet) {
                Text("Search Cabinet")
            }
        }
    }

    private func showInCabinet() {
        Task {
            try await PinupPopper().search(search)
        }
    }
}
