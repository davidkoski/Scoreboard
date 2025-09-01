//
//  VPinStudio.swift
//  Scoreboard
//
//  Created by David Koski on 6/8/24.
//

import Foundation

func bestScore(_ scores: [VPinStudio.Score]) -> VPinStudio.Score? {
    Set(scores.filter { $0.playerInitials == OWNER_INITIALS && $0.score > 0 }).sorted().last
}

struct WrappedError: Error {
    let base: Error
    let url: URL
}

private let localSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.httpMaximumConnectionsPerHost = 10
    return URLSession(configuration: configuration)
}()

private let maniaSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.httpMaximumConnectionsPerHost = 3
    return URLSession(configuration: configuration)
}()

/// Client for VPin Studio
///
/// - https://github.com/syd711/vpin-studio
///
/// This is for access to:
///
/// - scores
/// - tables on the cabinet
/// - vpin mania scores (global scoreboard)
public struct VPinStudio {

    let mediaURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/poppermedia")!

    /// read out existing score data
    let scoresURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/games/scores")!

    /// rescan scores -- report errors, e.g. No nvram file
    let scanScoreURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/games/scanscore")!

    let listURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/games/knowns/-1")!

    let detailsURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/frontend/tabledetails")!

    let activityURL = URL(string: "\(CABINET_URL):\(VPIN_STUDIO_PORT)/api/v1/alx")!

    let vpinManiaScoresURL = URL(string: "https://www.vpin-mania.net/api/highscores/table")!

    public func wheelImageURL(id: CabinetTableId) -> URL {
        mediaURL.appending(components: id.id, "Wheel")
    }

    public struct Score: Decodable, Hashable, Comparable {
        let playerInitials: String

        // "score": "48,104,320"
        let score: Int

        public static func < (lhs: VPinStudio.Score, rhs: VPinStudio.Score) -> Bool {
            lhs.score < rhs.score
        }
    }

    private struct ScoresResponse: Decodable {
        let scores: [Score]
    }

    public func getScores(id: CabinetTableId) async throws -> [Score] {
        let url = scoresURL.appending(components: id.id)
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await localSession.data(for: request)

            return try JSONDecoder().decode(ScoresResponse.self, from: data)
                .scores
        } catch {
            throw WrappedError(base: error, url: url)
        }
    }

    public enum ScoreStatus: String, Codable, Comparable {
        case ok

        /// duplicate table for the rom
        case duplicate

        /// do not have a high score entry yet
        case noScore = "no score"

        /// Found VPReg entry, but no highscore entries in it
        case empty

        /// No nvram file, VPReg.stg entry or highscore text file found.
        case noFile = "no file"

        /// The NV ram file \"empsback.nv\" is not supported by PINemHi
        case notSupported = "not supported"

        case unknown

        private var sortOrder: Int {
            switch self {
            case .ok: return 0
            case .duplicate: return 1
            case .noScore: return 2
            case .empty: return 3
            case .noFile: return 4
            case .notSupported: return 5
            case .unknown: return 6
            }
        }

        public static func < (lhs: VPinStudio.ScoreStatus, rhs: VPinStudio.ScoreStatus) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }

    private struct ScanScoresResponse: Decodable {
        // {"type":null,"displayName":null,"filename":null,"modified":null,"scanned":"2024-09-07T23:57:40.801+00:00","raw":null,"rom":"Great HOUDINI","status":"No nvram file, VPReg.stg entry or highscore text file found."}

        let type: String?
        let raw: String?
        let status: String?

        var disposition: ScoreStatus {
            if let status {
                if status.hasPrefix("Found VPReg entry, but no highscore entries in it") {
                    return .empty
                }
                if status.hasPrefix("No nvram file") {
                    return .noFile
                }
                if status.hasPrefix("The NV ram file") {
                    return .notSupported
                }

                print("Unknown score status: \(status)")

                return .unknown
            }

            return .noScore
        }
    }

    public func getScoreStatusForEmptyScore(id: CabinetTableId) async throws -> ScoreStatus {
        let url = scanScoreURL.appending(components: id.id)
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await localSession.data(for: request)

            return try JSONDecoder().decode(ScanScoresResponse.self, from: data)
                .disposition
        } catch {
            throw WrappedError(base: error, url: url)
        }
    }

    public enum HighScoreType: String, Codable, Comparable {
        case nvram = "NVRam"
        case em = "EM"
        case vpreg = "VPReg"
        case ini = "Ini"
        case na = "N/A"

        private var sortOrder: Int {
            switch self {
            case .nvram: return 0
            case .em: return 1
            case .vpreg: return 2
            case .ini: return 3
            case .na: return 4
            }
        }

        public static func < (lhs: HighScoreType, rhs: HighScoreType) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }

    /**

    ```json
     {
       "rom": "meteorb",
       "romAlias": null,
       "scannedRom": "meteorb",
       "scannedAltRom": null,
       "gameDisplayName": "Meteor (Stern 1979) Bord 1.0.0a VR",
       "gameFileName": "Meteor (Stern 1979) Bord 1.0.0a VR.vpx",
       "gameName": "Meteor (Stern 1979)",
       "tableName": null,
       "version": "1.0.0a",
       "disabled": false,
       "updateAvailable": false,
       "dateAdded": 1716325101648,
       "dateUpdated": 1744686253045,
       "id": 875,
       "nvOffset": 0,
       "hsFileName": null,
       "scannedHsFileName": null,
       "cardDisabled": false,
       "patchVersion": null,
       "gameStatus": 1,
       "emulatorId": 1,
       "validationState": {
         "code": 7,
         "options": []
       },
       "hasMissingAssets": false,
       "hasOtherIssues": false,
       "validScoreConfiguration": true,
       "ignoredValidations": [],
       "highscoreType": "NVRam",
       "altSoundAvailable": false,
       "altColorType": null,
       "competitionTypes": [],
       "nbDirectB2S": 1,
       "defaultBackgroundAvailable": true,
       "eventLogAvailable": true,
       "pupPackName": null,
       "templateId": null,
       "extTableId": "FrfsSwGv",
       "extTableVersionId": "JJV0r5tW",
       "extVersion": "1.0.0a",
       "comment": null,
       "launcher": "vpinballx.exe",
       "numberPlayed": 22,
       "foundControllerStop": true,
       "foundTableExit": true,
       "vrRoomSupport": true,
       "vrRoomEnabled": false,
       "rating": 4,
       "dmdgameName": null,
       "vpsUpdates": {
         "changes": [
           {
             "diffType": "rom",
             "id": "6CqzoD8qpc"
           }
         ],
         "empty": false
       },
       "romRequired": true,
       "romExists": true,
       "vpxGame": true,
       "dmdtype": null,
       "dmdprojectFolder": null,
       "fpGame": false,
       "gameFilePath": "D:\\vpx\\vPinball\\visualpinball\\Tables\\Meteor (Stern 1979) Bord 1.0.0a VR.vpx",
       "directB2SPath": "D:\\vpx\\vPinball\\visualpinball\\Tables\\Meteor (Stern 1979) Bord 1.0.0a VR.directb2s",
       "fxGame": false,
       "modified": 1730962734461,
       "gameFileSize": 93507584,
       "iniPath": "D:\\vpx\\vPinball\\visualpinball\\Tables\\Meteor (Stern 1979) Bord 1.0.0a VR.ini",
       "povPath": null,
       "resPath": "D:\\vpx\\vPinball\\visualpinball\\Tables\\Meteor (Stern 1979) Bord 1.0.0a VR.res"
     },
     ```

     */
    public struct TableListItem: Decodable {
        /// unique identifier for table, e.g. sMBqx5fp.  This is the identifier from the ``PinballDB``
        let webId: WebTableId

        /// short name, e.g. 2001 (Gottlieb 1971)
        let gameName: String

        /// long name, e.g. 2001 (Gottlieb 1971) Wrd1972 0.99a
        let gameDisplayName: String?

        /// numeric identifier (row id) for cabinet database
        let cabinetId: CabinetTableId
        let highscoreType: HighScoreType?

        let rom: String
        let hsFileName: String?
        let nvOffset: Int

        let disabled: Bool

        enum CodingKeys: String, CodingKey {
            case gameName
            case gameDisplayName
            case id = "extTableId"
            case popperId = "id"
            case rom
            case hsFileName
            case nvOffset
            case highscoreType
            case disabled
        }

        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(
                keyedBy: CodingKeys.self)

            self.gameName = try container.decode(String.self, forKey: CodingKeys.gameName)
            self.gameDisplayName = try container.decode(String.self, forKey: .gameDisplayName)
            self.webId = try container.decode(WebTableId.self, forKey: CodingKeys.id)
            self.cabinetId = try container.decode(CabinetTableId.self, forKey: CodingKeys.popperId)
            self.highscoreType = try container.decodeIfPresent(
                HighScoreType.self, forKey: .highscoreType)

            self.rom = try container.decodeIfPresent(String.self, forKey: .rom) ?? ""
            self.hsFileName = try container.decodeIfPresent(String.self, forKey: .hsFileName)
            self.nvOffset = try container.decode(Int.self, forKey: .nvOffset)

            self.disabled = try container.decode(Bool.self, forKey: .disabled)
        }

        var shortName: String {
            gameName.components(separatedBy: "(")[0]
        }

        var scoreId: ScoreId { ScoreId(self) }
    }

    /**

     http://pinbot.local:8089/api/v1/frontend/tabledetails/129

    ```json
     {
       "sqlVersion": 64,
       "emulatorId": 1,
       "status": 1,
       "gameName": "The Addams Family (Bally 1992)",
       "gameFileName": "The Addams Family (Bally 1992) G5k 2.4.41 VR.vpx",
       "gameDisplayName": "The Addams Family (Bally 1992) G5k 2.4.41 VR",
       "gameType": "SS",
       "gameVersion": "2.4.41",
       "dateAdded": 1714194095441,
       "dateModified": 1743395603391,
       "gameTheme": "Celebrities,Fictional,Licensed Theme,Movie",
       "notes": null,
       "gameYear": 1992,
       "romName": "taf_l7",
       "manufacturer": "Bally",
       "numberOfPlayers": 4,
       "lastPlayed": 1753848481661,
       "numberPlays": 47,
       "tags": "",
       "category": "",
       "author": "G5k, 3rdAxis, SliderPoint, VPW, DarthVito, Fluffhead35, DaRdog81, Passion4pins, RobbyKingPin, ClarkKent, TastyWasps, DGrimmReaper, Iaakki",
       "volume": null,
       "launchCustomVar": null,
       "keepDisplays": "",
       "gameRating": 5,
       "dof": null,
       "altRunMode": "",
       "url": "http://www.ipdb.org/machine.cgi?id=20",
       "designedBy": "Pat Lawlor",
       "altLaunchExe": null,
       "custom2": null,
       "custom3": "Wq40ng8f",
       "special": null,
       "mediaSearch": "",
       "custom4": null,
       "custom5": null,
       "webGameId": "aT_GONvw",
       "romAlt": null,
       "webLink2Url": null,
       "tourneyId": null,
       "mod": false,
       "gDetails": "VPS Comment:\nG5k Version\n\nPress F6 to configure MODs (disable exclusive to access)\n\nFor DMD colorization: http://vpuniverse.com/forums/topic/3746-the-addams-family-colorization/\n\nThanks to DJRobX and those who helped test.\n",
       "gNotes": null,
       "gLog": null,
       "gPlayLog": null,
       "hsFilename": null,
       "launcherList": [
         "VPinball8.exe",
         "VPinball921.exe",
         "VPinball995.exe",
         "VPinball99_PhysMod5_Updated.exe",
         "VPinballX.exe",
         "VPinballX106.exe",
         "VPinballX1074.exe",
         "VPinballX107_32bit.exe",
         "VPinballX64.exe",
         "VPinballX_GL64.exe"
       ],
       "ipdbnum": "20",
       "popper15": true
     }
     ```

     */
    public struct TableDetails: Decodable {
        let webGameId: WebTableId?

        let gameYear: Int

        enum GameType: String, Codable {
            case SS
            case EM
        }
        let gameType: GameType
        let manufacturer: String

        let gameTheme: String?
        var gameThemes: Set<String> {
            if let gameTheme {
                Set(gameTheme.components(separatedBy: ","))
            } else {
                []
            }
        }

        let author: String
        var firstAuthor: String { author.components(separatedBy: ",")[0] }

        let designedBy: String?
        var designers: Set<String> {
            if let designedBy {
                Set(designedBy.components(separatedBy: ","))
            } else {
                []
            }
        }
    }

    public func getTablesList() async throws -> [TableListItem] {
        let request = URLRequest(url: listURL)
        let (data, _) = try await localSession.data(for: request)

        return try JSONDecoder().decode([TableListItem].self, from: data)
    }

    public func getTablesDetail(cabinetId: CabinetTableId) async throws -> TableDetails {
        let url = detailsURL.appendingPathComponent(cabinetId.stringValue)
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await localSession.data(for: request)

            return try JSONDecoder().decode(TableDetails.self, from: data)
        } catch {
            throw WrappedError(base: error, url: url)
        }
    }

    public struct VPinManiaScores: Decodable {
        let data: [VPinManiaScore]
    }

    public struct VPinManiaScore: Decodable, Hashable {
        let score: Int
        let initials: String
        let displayName: String
        let creationDate: Date

        func asScore() -> Scoreboard.Score {
            Scoreboard.Score(initials: initials, score: score, date: creationDate)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(score)
            hasher.combine(initials)
        }

        public static func == (lhs: VPinManiaScore, rhs: VPinManiaScore) -> Bool {
            lhs.score == rhs.score && lhs.initials == rhs.initials
        }
    }

    public func getVPinManiaScores(id: WebTableId) async throws -> [VPinManiaScore] {
        let request = URLRequest(url: vpinManiaScoresURL.appending(components: id.description))
        let (data, _) = try await maniaSession.data(for: request)

        // 2024-07-30 03:58:39
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(f)

        return try decoder.decode(VPinManiaScores.self, from: data).data
    }

    public struct Activity: Decodable {
        /*
         {
           "uniqueId": 1068,
           "gameId": 1326,
           "lastPlayed": 1752896307367,
           "numberOfPlays": 2,
           "timePlayedSecs": 2266,
           "displayName": "City Hunter (Original 2025) Tombg 1.0.0 VR",
           "scores": 2,
           "highscores": 2
         },
         */

        let gameId: CabinetTableId
        let lastPlayed: Date
        let numberOfPlays: Int
        let timePlayedSecs: Int
    }

    public func getActivityDetails() async throws -> [Activity] {
        let request = URLRequest(url: activityURL)
        let (data, _) = try await localSession.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        struct Container: Decodable {
            let entries: [Activity]
        }

        return try decoder.decode(Container.self, from: data).entries
    }

}
