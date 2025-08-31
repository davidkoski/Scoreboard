//
//  TableView.swift
//  Scoreboard
//
//  Created by David Koski on 5/28/24.
//

import Foundation
import SwiftUI

struct TableDetailView: View {

    let document: ScoreboardDocument

    @Binding var path: NavigationPath
    @Binding var search: String
    @State var localSearch = ""

    @Binding var table: Table
    @Binding var scores: TableScoreboard
    @State var sortedScores = [Score]()

    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?

    @State var isPrimaryForHighScore = false
    @State var primaryForHighScore: Table?

    @State var vpinManiaScores: [Score]?

    @State private var confirmationShown = false

    @State private var sortOrder = [KeyPathComparator(\Score.score, order: .reverse)]

    @FocusState var searchFocused: Bool
    @FocusState var viewFocused: Bool

    var hideWhileEditing: Bool {
        #if os(iOS)
            showScore
        #else
            false
        #endif
    }

    var scoreBinding: Binding<Score> {
        Binding {
            score ?? .init(initials: OWNER_INITIALS, score: 0, date: Date())
        } set: { newValue in
            self.score = newValue
        }
    }

    func showPlays() -> some View {
        struct Row: Identifiable, Comparable {
            let title: String
            let score: Activity.Snapshot
            var id: CabinetTableId

            init(_ table: Table, document: ScoreboardDocument) {
                self.title = table.variant
                self.id = table.id
                self.score = document.contents.activity.snapshot(table) ?? .zero
            }

            init(sum: Activity.Snapshot) {
                self.title = "ALL"
                self.id = .init(stringValue: "ALL")!
                self.score = sum
            }

            static func < (lhs: Row, rhs: Row) -> Bool {
                lhs.score.lastPlayed < rhs.score.lastPlayed
            }
        }
        var data = document.contents.variations(table).map { Row($0, document: document) }
        if data.count > 1 {
            data.append(.init(sum: data.reduce(.zero) { $0 + $1.score }))
        }

        return VStack {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 200), alignment: .leading),
                    GridItem(.fixed(40), alignment: .trailing),
                    GridItem(.fixed(80), alignment: .trailing),
                    GridItem(.fixed(80), alignment: .trailing),
                ], spacing: 8
            ) {
                Group {
                    Text("Variant").bold()
                    Text("Plays").bold()
                    Text("Time").bold()
                    Text("Last").bold()
                }

                ForEach(data) { item in
                    Text(item.title)
                    Text(item.score.numberOfPlays.description)
                    Text(item.score.timePlayedSecs.description)
                    Text(item.score.lastPlayed.description)
                }
            }
            .padding(3)
            .border(.primary)
        }
    }

    var body: some View {
        VStack {
            HStack {
                if !hideWhileEditing {
                    AsyncImage(url: VPinStudio().wheelImageURL(id: table.cabinetId)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 192, maxHeight: 144)
                    } placeholder: {
                        EmptyView()
                    }
                }

                VStack {
                    HStack {
                        Spacer()

                        Image(systemName: table.vr.imageName)
                        Spacer().frame(width: 8)

                        Text(table.longDisplayName)
                            .font(.headline)

                        scoreStatus

                        showPlays()

                        Spacer()
                    }

                    if let primaryForHighScore {
                        HStack {
                            Spacer()
                            Text("Primary for NVRam: ")
                            Text(primaryForHighScore.longDisplayName)
                            Spacer()
                        }
                    }

                    if !hideWhileEditing {
                        HStack {
                            Button(action: createNewScoreFromCamera) {
                                Image(systemName: "camera")
                            }

                            Button(action: createNewScoreFromKeyboard) {
                                Image(systemName: "keyboard")
                            }

                            if isPrimaryForHighScore {
                                Button(action: downloadScores) {
                                    Image(systemName: "square.and.arrow.down")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .disabled(showScore || !isPrimaryForHighScore)
                    }
                }
            }

            VStack {
                if showScore {
                    if showCamera {
                        ScoreCameraView(score: scoreBinding.score)
                    }

                    ScoreEntry(score: scoreBinding, save: saveScore, cancel: cancelScore)
                }

                #if os(iOS)
                    if showScore {
                        ScoreKeypad(score: scoreBinding)
                    }
                #endif

                if !hideWhileEditing {
                    SwiftUI.Table(sortOrder: $sortOrder) {
                        TableColumn("Initials", value: \.initials) { score in
                            Text(score.initials)
                                .bold(score.isLocal)
                        }
                        .width(75)
                        TableColumn("Score", value: \.score) { score in
                            Text(score.score.formatted())
                                .frame(alignment: .trailing)
                                .bold(score.isLocal)
                        }
                        .width(200)
                        TableColumn("Date", value: \.date) { score in
                            Text(score.date.formatted())
                                .bold(score.isLocal)
                        }
                        .width(200)
                    } rows: {
                        ForEach(sortedScores) { score in
                            if score.isLocal {
                                TableRow(score)
                                    .contextMenu {
                                        Button(action: { delete(score: score) }) {
                                            Text("Delete")
                                        }
                                    }
                            } else {
                                TableRow(score)
                            }
                        }
                    }
                    .onChange(of: sortOrder) {
                        sortedScores = scores.entries.sorted(using: sortOrder)
                    }
                    .onChange(of: scores) {
                        // if the scoreboard changes
                        sortedScores = scores.entries.sorted(using: sortOrder)
                    }
                    .focused($viewFocused)
                    .task {
                        // put focus on the view so cmd-f will work (as expected)
                        viewFocused = true

                        sortedScores = scores.entries.sorted(using: sortOrder)
                    }
                }
            }
        }
        .padding()
        .toolbar {
            Button(action: showVpinMania) {
                Text("VPin Mania")
            }
            Button(action: showInCabinet) {
                Text("Show In Cabinet")
            }
        }

        .searchable(text: $localSearch)
        .searchFocused($searchFocused)
        .onSubmit(
            of: .search,
            {
                path.removeLast(path.count)
                search = localSearch
            }
        )
        .onKeyPress { keypress in
            if keypress.key == "f" && keypress.modifiers.contains(.command) {
                searchFocused = true
                return .handled
            }
            return .ignored
        }

        .task {
            // if we can't collect the score, indicate which table is primary
            isPrimaryForHighScore = !document.contents.hasMisconfiguredScores(table)
            if !isPrimaryForHighScore {
                primaryForHighScore = document.contents.representative(table.scoreId)
            }
        }
        .onChange(of: table) {
            vpinManiaScores = nil
        }
    }

    var scoreStatus: some View {
        Group {
            if table.scoreType != nil || table.scoreStatus != .ok {
                Spacer().frame(width: 20)
                Text(table.scoreStatus?.rawValue ?? "unknown")
                    .italic()
                if let scoreType = table.scoreType {
                    Spacer().frame(width: 20)
                    Text(scoreType.rawValue)
                }
            }
        }
    }

    private func combinedScores() -> [Score] {
        if let vpinManiaScores {
            (scores.entries + vpinManiaScores).sorted()
        } else {
            scores.entries.sorted()
        }
    }

    private func showVpinMania() {
        Task {
            do {
                let scores = try await VPinStudio().getVPinManiaScores(id: table.webId)
                self.scores.mergeVPinManiaScores(scores)
            } catch {
                print("Error fetching vpin mania scores: \(error)")
            }
        }
    }

    private func showInCabinet() {
        Task {
            try await PinupPopper().search(table.name)
        }
    }

    @MainActor
    private func delete(score: Score) {
        withAnimation {
            scores.remove(score)
        }
    }

    private func createNewScoreFromCamera() {
        withAnimation {
            score = Score(initials: OWNER_INITIALS, score: 0)
            self.showScore = true
            self.showCamera = true
        }
    }

    private func createNewScoreFromKeyboard() {
        withAnimation {
            score = Score(initials: OWNER_INITIALS, score: 0)
            self.showScore = true
        }
    }

    private func stopScore() {
        self.score = nil
        self.showScore = false
        self.showCamera = false
    }

    @MainActor
    private func saveScore(_ score: Score) {
        scores.add(score)
    }

    @MainActor
    private func saveScore() {
        withAnimation {
            if let score {
                saveScore(score)
            }
            stopScore()
        }
    }

    private func cancelScore() {
        withAnimation {
            stopScore()
        }
    }

    private func downloadScores() {
        let id = table.cabinetId

        if document.contents.hasMisconfiguredScores(table) {
            // the score can't be saved with the scoreId
            return
        }

        Task {
            let allScores = try await VPinStudio().getScores(id: id)

            if let best = bestScore(allScores) {
                if !scores.entries.contains(where: { $0.score == best.score }) {
                    await MainActor.run {
                        withAnimation {
                            saveScore(.init(initials: OWNER_INITIALS, score: best.score))
                        }
                    }
                }
            }
        }
    }
}
