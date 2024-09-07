//
//  VPinStudio.swift
//  Scoreboard
//
//  Created by David Koski on 6/8/24.
//

import Foundation

// http://pinbot.local:8089/api/v1/poppermedia/124/Wheel

func bestScore(_ scores: [VPinStudio.Score]) -> VPinStudio.Score? {
    Set(scores.filter { $0.playerInitials == OWNER_INITIALS && $0.numericScore > 0 }).sorted().last
}

struct WrappedError : Error {
    let base: Error
    let url: URL
}

struct VPinStudio {
    
    let mediaURL = URL(string: "http://pinbot.local:8089/api/v1/poppermedia")!
    
    let scoresURL = URL(string: "http://pinbot.local:8089/api/v1/games/scores")!
    
    let listURL = URL(string: "http://pinbot.local:8089/api/v1/games/knowns/-1")!
    
    let detailsURL = URL(string: "http://pinbot.local:8089/api/v1/popper/tabledetails")!

    let vpinManiaScoresURL = URL(string: "https://www.vpin-mania.net/api/highscores/table")!

    public func wheelImageURL(id: String) -> URL {
        mediaURL.appending(components: id, "Wheel")
    }
    
    public struct Score : Decodable, Hashable, Comparable {
        let playerInitials: String
    
        // "score": "48,104,320"
        let score: String
        let numericScore: Int
        
        public static func < (lhs: VPinStudio.Score, rhs: VPinStudio.Score) -> Bool {
            lhs.numericScore < rhs.numericScore
        }
        
        private enum CodingKeys: CodingKey {
            case playerInitials
            case score
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<VPinStudio.Score.CodingKeys> = try decoder.container(keyedBy: VPinStudio.Score.CodingKeys.self)
            
            self.playerInitials = try container.decode(String.self, forKey: VPinStudio.Score.CodingKeys.playerInitials)
            self.score = try container.decode(String.self, forKey: VPinStudio.Score.CodingKeys.score)
            
            let strippedScore = score
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            self.numericScore = Int(strippedScore) ?? 0
        }
    }

    private struct ScoresResponse : Decodable {
        let scores: [Score]
    }
    
    public func getScores(id: String) async throws -> [Score] {
        let url = scoresURL.appending(components: id)
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            return try JSONDecoder().decode(ScoresResponse.self, from: data)
                .scores
        } catch {
            throw WrappedError(base: error, url: url)
        }
    }
    
    public struct TableDetails : Decodable {
        let id: String
        let gameName: String
        let popperId: String
        let rom: String
        let highscoreType: String?
        
        /// true if this uses nvram high scoring -- in particular the high scores are per rom name
        var isNVRam: Bool { highscoreType == "NVRam" }
        
        enum CodingKeys: String, CodingKey {
            case gameName
            case id = "extTableId"
            case popperId = "id"
            case rom
            case highscoreType
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            
            self.gameName = try container.decode(String.self, forKey: CodingKeys.gameName)
            self.id = try container.decode(String.self, forKey: CodingKeys.id)
            self.popperId = try container.decode(Int.self, forKey: CodingKeys.popperId).description
            self.rom = try container.decode(String.self, forKey: .rom)
            self.highscoreType = try container.decodeIfPresent(String.self, forKey: .highscoreType)
        }
    }
    
    public func getTablesList() async throws -> [TableDetails] {
        let request = URLRequest(url: listURL)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode([TableDetails].self, from: data)
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
    
    public struct VPinManiaScore: Decodable {
        let score: Int
        let initials: String
        let displayName: String
        let creationDate: Date
    }
    
    public func getVPinManiaScores(id: String) async throws -> [VPinManiaScore] {
        let request = URLRequest(url: vpinManiaScoresURL.appending(components: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 2024-07-30 03:58:39
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(f)
        
        return try decoder.decode([VPinManiaScore].self, from: data)
    }
}
