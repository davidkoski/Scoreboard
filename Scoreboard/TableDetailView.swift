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

    @Binding var table: Table
    @Binding var scores: TableScoreboard

    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?

    @State var isPrimaryForHighScore = false
    @State var primaryForHighScore: Table?

    @State var vpinManiaScores: [Score]?

    @State private var confirmationShown = false

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
                        Text(table.name)
                            .font(.headline)

                        scoreStatus

                        Spacer()
                    }

                    if let primaryForHighScore {
                        HStack {
                            Spacer()
                            Text("Primary for NVRam: ")
                            Text(primaryForHighScore.name)
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
                        .disabled(showScore)
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
                    List {
                        ForEach(combinedScores()) { score in
                            HStack {
                                Text(score.initials)
                                    .frame(width: 50)
                                Text(score.score.formatted())
                                    .frame(width: 200, alignment: .trailing)
                                Text(score.date.formatted())
                                    .frame(width: 200)
                            }
                            .bold(score.initials == OWNER_INITIALS)
                            .contextMenu {
                                Button(action: { delete(score: score) }) {
                                    Text("Delete")
                                }
                            }
                        }
                        .onDelete { indexes in
                            if let index = indexes.first {
                                delete(score: scores.entries[index])
                            }
                        }
                    }
                    .focused($viewFocused)
                    .task {
                        // put focus on the view so cmd-f will work (as expected)
                        viewFocused = true
                    }
                }
            }
        }
        .toolbar {
            Button(action: showVpinMania) {
                Text("VPin Mania")
            }
        }

        .searchable(text: $search)
        .searchFocused($searchFocused)
        .onSubmit(
            of: .search,
            {
                path.removeLast(path.count)
                path.append("Tables")
            }
        )
        .onAppear {
            // reset the search
            search = ""
        }
        .onKeyPress { keypress in
            if keypress.key == "f" && keypress.modifiers.contains(.command) {
                searchFocused = true
                return .handled
            }
            return .ignored
        }

        .task {
            // if we can't collect the score, indicate which table is primary
            if document.contents.hasMisconfiguredScores(table) {
                isPrimaryForHighScore = false
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

                withAnimation {
                    self.vpinManiaScores =
                        scores
                        .filter {
                            // filter out my local scores
                            $0.initials != OWNER_INITIALS
                        }
                        .map {
                            Score(initials: $0.initials, score: $0.score, date: $0.creationDate)
                        }
                }
            } catch {
                print("Error fetching vpin mania scores: \(error)")
            }
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
                if !scores.entries.contains(where: { $0.score == best.numericScore }) {
                    await MainActor.run {
                        withAnimation {
                            saveScore(.init(initials: OWNER_INITIALS, score: best.numericScore))
                        }
                    }
                }
            }
        }
    }
}
