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

    struct Table: Decodable {
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

    private struct TableJustGameID: Decodable {
        let gameID: Int

        enum CodingKeys: String, CodingKey {
            case gameID = "GameID"
        }
    }

    public func currentTableId() async throws -> String? {
        do {
            let request = URLRequest(url: getItem)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let table = try? JSONDecoder().decode(Table.self, from: data) {
                return table.id
            }

            // if the game is not running but is selected in popper we only have
            // the gameId (primary key in the popper db)
            if let gameIdTable = try? JSONDecoder().decode(TableJustGameID.self, from: data) {
                return gameIdTable.gameID.description
            }
            
            return nil
            
        } catch {
            throw WrappedError(base: error, url: getItem)
        }
    }

    public func search(_ string: String) async throws {
        let url = search.appending(path: string)
        _ = try await URLSession.shared.data(from: url)
    }
}
