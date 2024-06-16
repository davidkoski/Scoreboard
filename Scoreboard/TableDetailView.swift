//
//  TableView.swift
//  Scoreboard
//
//  Created by David Koski on 5/28/24.
//

import Foundation
import SwiftUI
import SwiftData

struct CurrentTableDetailView: View {
    
    @Environment(\.modelContext) private var modelContext

    @State var table: Table?
    
    var body: some View {
        Group {
            if let table {
                TableDetailView(table: table)
            } else {
                ProgressView()
            }
        }
        .task {
            await selectCurrent()
        }
    }
    
    private func selectCurrent() async {
        do {
            guard let current = try await PinupPopper().currentTable() else {
                print("Unable to get current from PinupPopper")
                return
            }
            let id = current.id
            
            let tables = try modelContext.fetch(FetchDescriptor<Table>(predicate: #Predicate<Table> {
                $0.id == id
            }))
            
            if let table = tables.first {
                self.table = table
                
                // backfill missing popperId
                if table.popperId == nil {
                    table.popperId = current.gameID
                }
                
            } else {
                self.table = Table(id: current.id, name: current.name, popperId: current.gameID)
            }
            
        } catch {
            print("Unable to get current: \(error)")
        }
    }
}

struct TableDetailView : View {
    let table: Table
    
    @State var showScore = false
    @State var showCamera = false
    @State var score: Score?
    
    @Environment(\.modelContext) private var modelContext
    
    @Query var allTags: [Tag]

    @State private var sortOrder = [KeyPathComparator(\Score.score, order: .reverse)]
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
            score ?? .init(person: "DAK", score: 0)
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
                            .frame(maxWidth: 144, maxHeight: 144)
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
                        
                        HStack {
                            ForEach(allTags.sorted(), id: \.tag) { tag in
                                let selected = table.tags.contains(tag)
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
                                        if table.tags.contains(tag) {
                                            table.tags.removeAll { $0 == tag }
                                        } else {
                                            table.tags.append(tag)
                                        }
                                        try? modelContext.save()
                                    }
                                    .help(tag.tag)
                            }
                        }
                        #if os(iOS)
                        .font(.system(size: 32))
                        #else
                        #endif
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
            table.scores.removeAll { $0 == score }
            modelContext.delete(score)
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
    
    private func saveScore(_ score: Score) {
        if table.modelContext == nil {
            modelContext.insert(table)
        }
        table.scores.append(score)
        do {
            try modelContext.save()
        } catch {
            print("Failed saving score: \(error)")
        }
    }
    
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
                        saveScore(.init(person: "DAK", score: best.numericScore))

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

