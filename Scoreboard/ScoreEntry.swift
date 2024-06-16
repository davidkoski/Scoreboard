//
//  ScoreEntry.swift
//  Scoreboard
//
//  Created by David Koski on 6/15/24.
//

import Foundation
import SwiftUI

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
