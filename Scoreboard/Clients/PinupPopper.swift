//
//  Pinball.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation

/// Interface to PinupPopper.
///
/// - https://www.nailbuster.com/wikipinup/doku.php?id=start
///
/// This can read the currently selected game and execute a search in the Popper UI.
struct PinupPopper {

    let getItem = URL(string: "\(CABINET_URL)/function/getcuritem")!
    let search = URL(string: "\(CABINET_URL)/function/findgame")!

    struct Table: Decodable {
        let name: String
        let id: WebTableId
        let gameID: CabinetTableId

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
        let gameID: CabinetTableId

        enum CodingKeys: String, CodingKey {
            case gameID = "GameID"
        }
    }

    public func currentTableId() async throws -> CabinetTableId? {
        do {
            let request = URLRequest(url: getItem)
            let (data, _) = try await URLSession.shared.data(for: request)

            if let table = try? JSONDecoder().decode(Table.self, from: data) {
                return table.gameID
            }

            // if the game is not running but is selected in popper we only have
            // the gameId (primary key in the popper db)
            if let gameIdTable = try? JSONDecoder().decode(TableJustGameID.self, from: data) {
                return gameIdTable.gameID
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
