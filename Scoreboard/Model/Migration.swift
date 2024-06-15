//
//  Migration.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftData

struct ScoreboardCardsMigrationPlan: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [
        ScoreboardVersionedSchema1.self,
        ScoreboardVersionedSchema2.self,
    ]
    
    static let stages: [MigrationStage] = [
        .lightweight(
            fromVersion: ScoreboardVersionedSchema1.self,
            toVersion: ScoreboardVersionedSchema2.self)
    ]
}

struct ScoreboardVersionedSchema1: VersionedSchema {
    static let models: [any PersistentModel.Type] = [Table.self, Score.self]
    static let versionIdentifier: Schema.Version = .init(1, 0, 0)
    
    @Model
    final class Table : Equatable, Identifiable {
        @Attribute(.unique)
        var id: String
        
        var name: String
        
        @Relationship(deleteRule: .cascade)
        var scores: [Score]
        
        internal init(id: String, name: String) {
            self.id = id
            self.name = name
            self.scores = []
        }
    }

    @Model
    final class Score {
        var person: String
        var score: Int
        var date: Date
        
        @Relationship(inverse: \Table.scores)
        var table: Table?
        
        internal init(person: String, score: Int, date: Date = Date()) {
            self.person = person
            self.score = score
            self.date = date
        }
    }

}

struct ScoreboardVersionedSchema2: VersionedSchema {
    static let models: [any PersistentModel.Type] = [
        Table.self, Score.self, Tag.self
    ]
    
    static let versionIdentifier: Schema.Version = .init(2, 0, 0)
}
