//
//  TableView.swift
//  Scoreboard
//
//  Created by David Koski on 5/28/24.
//

import Foundation
import SwiftUI

enum Show {
    case table
    case topper
}

struct TableDetailView : View {
    let entry: PinballDB.Entry
    let table: Table
    
    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?
    
    @Environment(\.modelContext) private var modelContext

    @State private var sortOrder = [KeyPathComparator(\Score.score, order: .reverse)]
    @State private var confirmationShown = false
    
    @Binding var show: Show
    
    var showScoreTable: Bool {
        #if os(iOS)
        !showScore
        #else
        true
        #endif
    }
    
    var scoreBinding: Binding<Score> {
        Binding {
            score ?? .init(person: "DAK", score: 0)
        } set: { newValue in
            self.score = newValue
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                if let popperId = table.popperId {
                    AsyncImage(url: VPinStudio().wheelImageURL(id: popperId)) { image in
                        image
                            .resizable()
                            .frame(maxWidth: 64, maxHeight: 64)
                    } placeholder: {
                        EmptyView()
                    }
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Text(entry.title)
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: createNewScoreFromCamera) {
                            Image(systemName: "camera")
                        }
                        
                        Button(action: createNewScoreFromKeyboard) {
                            Image(systemName: "keyboard")
                        }

                        Button(action: downloadScores) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .disabled(table.popperId == nil)
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .disabled(showScore)
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

                if showScoreTable {
                    let scores = table.scores.sorted(using: sortOrder)
                    
                    SwiftUI.Table(scores, sortOrder: $sortOrder) {
                        TableColumn("Name", value: \.person)
                            .width(min: 50, max: 50)
                        
                        TableColumn("Score", value: \.score) { score in
                            Text(score.score.formatted())
                        }
                        TableColumn("Date", value: \.date) { score in
                            Text(score.date.formatted())
                        }
                        TableColumn("") { score in
                            Button(role: .destructive, action: { confirmationShown = true }) {
                                Image(systemName: "trash")
                            }
                            .confirmationDialog(
                                "Are you sure?",
                                isPresented: $confirmationShown
                            ) {
                                Button("Yes") {
                                    delete(score: score)
                                }
                            }
                        }
                        .width(min: 30, max: 30)
                    }
                }
            }
        }
    }
    
    private func delete(score: Score) {
        withAnimation {
            do {
                table.scores.removeAll { $0 == score }
                modelContext.delete(score)
                try modelContext.save()
            } catch {
                print("failed to delete score: \(error)")
            }
        }
    }

    private func createNewScoreFromCamera() {
        withAnimation {
            score = Score(person: "DAK", score: 0)
            self.showScore = true
            self.showCamera = true
        }
    }
    
    private func createNewScoreFromKeyboard() {
        withAnimation {
            score = Score(person: "DAK", score: 0)
            self.showScore = true
        }
    }
    
    private func stopScore() {
        self.score = nil
        self.showScore = false
        self.showCamera = false
    }
    
    private func saveScore(_ score: Score) throws {
        if table.modelContext == nil {
            modelContext.insert(table)
        }
        table.scores.append(score)
        try modelContext.save()
    }
    
    private func saveScore() {
        withAnimation {
            do {
                if let score {
                    try saveScore(score)
                }
            } catch {
                print("Unable to save score: \(error)")
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
        guard let id = table.popperId else { return }
        
        Task {
            let allScores = try await VPinStudio().getScores(id: id)
            
            let myScores = Set(
                allScores
                    .filter {
                        $0.playerInitials == "DAK"
                    }
            )
            .sorted()
            
            if let best = myScores.last {
                if !table.scores.contains(where: { $0.score == best.numericScore }) {
                    withAnimation {
                        do {
                            try saveScore(.init(person: "DAK", score: best.numericScore))
                        } catch {
                            print("Unable to save score: \(error)")
                        }
                        
                        // how do we get swiftui to notice the change
                        // in table.scores relationship?  here I touch
                        // the sortOrder as a workaround to force it
                        // to refresh
                        
                        let old = self.sortOrder
                        self.sortOrder = []
                        self.sortOrder = old
                    }
                }
            }
        }
    }
}

struct ScoreEntry : View {
    
    @Binding var score: Score
    
    let save: () -> Void
    let cancel: () -> Void
    
    @FocusState private var scoreIsFocused: Bool

    var body: some View {
        HStack {
            TextField("initials", text: $score.person)
            
            #if os(iOS)
            TextField("score", value: $score.score, format: .number)
                .focused($scoreIsFocused)
                .keyboardType(.decimalPad)
                .onSubmit {
                    save()
                }
            #else
            TextField("score", value: $score.score, format: .number)
                .focused($scoreIsFocused)
                .onSubmit {
                    scoreIsFocused = false
                    save()
                }
            #endif
            
            Button("Save", action: {
                scoreIsFocused = false
                save()
            })
            Button("Cancel", action: {
                scoreIsFocused = false
                cancel()
            })
        }
        .onAppear {
            #if os(iOS)
            #else
            scoreIsFocused = true
            #endif
        }
    }
    
}

struct ScoreKeypad : View {
    
    @Binding var score: Score
    
    struct Digit : View {
        @Binding var score: Score
        
        let value: Int

        var body: some View {
            Button(action: add) {
                Text("\(value)")
            }
        }
        
        func add() {
            score.score = score.score * 10 + value
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Digit(score: $score, value: 1)
                Digit(score: $score, value: 2)
                Digit(score: $score, value: 3)
            }
            HStack(spacing: 20) {
                Digit(score: $score, value: 4)
                Digit(score: $score, value: 5)
                Digit(score: $score, value: 6)
            }
            HStack(spacing: 20) {
                Digit(score: $score, value: 7)
                Digit(score: $score, value: 8)
                Digit(score: $score, value: 9)
            }
            HStack(spacing: 20) {
                Button(action: reset) {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                
                Digit(score: $score, value: 0)
                
                Button(action: backspace) {
                    Image(systemName: "delete.backward")
                }
                .buttonStyle(.plain)

            }
        }
        .fontDesign(.monospaced)
        .bold()
        .font(.system(size: 40))
        .buttonStyle(.bordered)
    }
    
    func reset() {
        score.score = 0
    }
    
    func backspace() {
        score.score = score.score / 10
    }
}

#Preview {
    ScoreKeypad(score: .constant(.init(person: "DAK", score: 1234)))
}
