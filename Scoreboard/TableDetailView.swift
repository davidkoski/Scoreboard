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
    @Binding var table: Table
    let tags: [Tag]

    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?

    @State var isPrimaryForHighScore = false
    @State var primaryForHighScore: Table?

    @State var vpinManiaScores: [Score]?

    @State private var confirmationShown = false

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
                    AsyncImage(url: VPinStudio().wheelImageURL(id: table.popperId)) { image in
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

                        // not really doing much with tags
                        // tagsView()
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
                                delete(score: table.scores[index])
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            Button(action: showVpinMania) {
                Text("VPin Mania")
            }
        }
        .task {
            isPrimaryForHighScore = document.isPrimaryForHighScore(table)
            if !isPrimaryForHighScore {
                primaryForHighScore = document.primaryForHighScore(table)
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
                    Text(scoreType)
                }
            }
        }
    }

    private func tagsView() -> some View {
        HStack {
            ForEach(tags) { tag in
                let selected = table.tags.contains(tag.tag)

                #if os(iOS)
                    let background = Color(white: 0.1)
                #else
                    let background = Color(white: 0.9)
                #endif

                display(tag: tag)
                    .foregroundStyle(.black)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(selected ? .white : background)
                        Circle()
                            .foregroundStyle(selected ? .white : Color(white: 0.8))
                            .padding(6)
                    }
                    .onTapGesture {
                        if table.tags.contains(tag.tag) {
                            table.tags.remove(tag.tag)
                        } else {
                            table.tags.insert(tag.tag)
                        }
                    }
                    .help(tag.tag)
            }
        }
        #if os(iOS)
            .font(.system(size: 32))
        #else
        #endif
    }

    private func combinedScores() -> [Score] {
        if let vpinManiaScores {
            (table.scores + vpinManiaScores).sorted()
        } else {
            table.scores.sorted()
        }
    }

    private func showVpinMania() {
        Task {
            do {
                let scores = try await VPinStudio().getVPinManiaScores(id: table.id)

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
            table.scores.removeAll { $0 == score }
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
        table.scores.append(score)
        table.scores.sort()
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
        let id = table.popperId

        Task {
            let allScores = try await VPinStudio().getScores(id: id)

            if let best = bestScore(allScores) {
                if !table.scores.contains(where: { $0.score == best.numericScore }) {
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
