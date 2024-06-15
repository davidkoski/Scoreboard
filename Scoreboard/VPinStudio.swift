//
//  VPinStudio.swift
//  Scoreboard
//
//  Created by David Koski on 6/8/24.
//

import Foundation

// http://pinbot.local:8089/api/v1/poppermedia/124/Wheel

struct VPinStudio {
    
    let mediaURL = URL(string: "http://pinbot.local:8089/api/v1/poppermedia")!
    
    let scoresURL = URL(string: "http://pinbot.local:8089/api/v1/games/scorehistory")!
    
    let detailsURL = URL(string: "http://pinbot.local:8089/api/v1/popper/tabledetails")!
    
    public func wheelImageURL(id: String) -> URL {
        mediaURL.appending(components: id, "Wheel")
    }
    
    public struct Score : Codable, Hashable, Comparable {
        let playerInitials: String
        let numericScore: Int
        
        public static func < (lhs: VPinStudio.Score, rhs: VPinStudio.Score) -> Bool {
            lhs.numericScore < rhs.numericScore
        }
    }

    private struct ScoresResponse : Codable {
        struct ScoreCollection : Codable {
            let scores: [Score]
        }
        
        let scores: [ScoreCollection]
    }
    
    public func getScores(id: String) async throws -> [Score] {
        let request = URLRequest(url: scoresURL.appending(components: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode(ScoresResponse.self, from: data)
            .scores
            .flatMap {
                $0.scores
            }
    }
    
    public struct TableDetailsShort : Codable {
        let gameName: String
        let id: String
        
        enum CodingKeys: String, CodingKey {
            case gameName
            case id = "webGameId"
        }
    }

    public func getDetailsShort(id: String) async throws -> TableDetailsShort {
        let request = URLRequest(url: detailsURL.appending(components: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode(TableDetailsShort.self, from: data)
    }
}
