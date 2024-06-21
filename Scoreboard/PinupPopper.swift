//
//  Pinball.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation

struct PinupPopper {
    
    let getItem = URL(string: "http://pinbot.local/function/getcuritem")!
    let search = URL(string: "http://pinbot.local/function/findgame")!

    struct Table : Decodable {
        let name: String
        let id: String
        let gameID: String
        
        var trimmedName: String {
            name
                .prefix { $0 != "(" }
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        enum CodingKeys: String, CodingKey {
            case name = "GameName"
            case id = "WEBGameID"
            case gameID = "GameID"
        }
    }
    
    private struct TableJustGameID : Decodable {
        let gameID: Int
        
        enum CodingKeys: String, CodingKey {
            case gameID = "GameID"
        }
    }

    
    public func currentTable() async throws -> Table? {
        let request = URLRequest(url: getItem)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let table = try? JSONDecoder().decode(Table.self, from: data) {
            return table
        }
        
        // if the game is not running but is selected in popper we only have
        // the gameId (primary key in the popper db)
        if let gameIdTable = try? JSONDecoder().decode(TableJustGameID.self, from: data) {
            let gameID = gameIdTable.gameID.description
            let info = try await VPinStudio().getDetailsShort(id: gameID)
            
            return .init(name: info.gameName, id: info.id, gameID: gameID)
        }
        
        return nil
    }
    
    public func search(_ string: String) async throws {
        let url = search.appending(path: string)
        _ = try await URLSession.shared.data(from: url)
    }
}
