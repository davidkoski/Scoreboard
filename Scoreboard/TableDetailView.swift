//
//  TableView.swift
//  Scoreboard
//
//  Created by David Koski on 5/28/24.
//

import Foundation
import SwiftUI

struct TableDetailView : View {
    
    @Binding var table: Table
    let tags: [Tag]
    
    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?
    
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
            score ?? .init(initials: "DAK", score: 0, date: Date())
        } set: { newValue in
            self.score = newValue
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                if !hideWhileEditing, let popperId = table.popperId {
                    AsyncImage(url: VPinStudio().wheelImageURL(id: popperId)) { image in
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
                        Spacer()
                    }
                    
                    if !hideWhileEditing {
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
                        ForEach(table.scores) { score in
                            HStack {
                                Text(score.initials)
                                    .frame(width: 50)
                                Text(score.score.formatted())
                                    .frame(width: 200, alignment: .trailing)
                                Text(score.date.formatted())
                                    .frame(width: 200)
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
    
    private func showVpinMania() {
        
    }
    
    @MainActor
    private func delete(score: Score) {
        withAnimation {
            table.scores.removeAll { $0 == score }
        }
    }

    private func createNewScoreFromCamera() {
        withAnimation {
            score = Score(initials: "DAK", score: 0)
            self.showScore = true
            self.showCamera = true
        }
    }
    
    private func createNewScoreFromKeyboard() {
        withAnimation {
            score = Score(initials: "DAK", score: 0)
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
        guard let id = table.popperId else { return }
        
        Task {
            let allScores = try await VPinStudio().getScores(id: id)
            
            if let best = bestScore(allScores) {
                if !table.scores.contains(where: { $0.score == best.numericScore }) {
                    await MainActor.run {
                        withAnimation {
                            saveScore(.init(initials: "DAK", score: best.numericScore))
                        }
                    }
                }
            }
        }
    }
}

