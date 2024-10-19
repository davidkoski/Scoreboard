//
//  PinballDB.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import SwiftUI

/// Interface to pinball db (list of all available games).
///
/// - https://virtualpinballspreadsheet.github.io
public actor PinballDB: ObservableObject {

    private let url = URL(
        string:
            "https://raw.githubusercontent.com/VirtualPinballSpreadsheet/vps-db/main/db/vpsdb.json")!

    public struct File: Decodable, Hashable, Comparable {
        let id: String?
        let updatedAt: Int?
        let imgUrl: String?
        let authors: [String]?
        let features: [String]?

        var url: URL? {
            if let imgUrl {
                URL(string: imgUrl)
            } else {
                nil
            }
        }

        public static func < (lhs: PinballDB.File, rhs: PinballDB.File) -> Bool {
            (lhs.updatedAt ?? 0) < (rhs.updatedAt ?? 0)
        }
    }

    public struct Entry: Decodable, Hashable {
        let id: String
        let name: String
        let manufacturer: String?
        let year: Int?
        let theme: Set<String>?
        let designers: Set<String>?
        let features: Set<String>?

        let tableFiles: [File]?
        let b2sFiles: [File]?

        var tableURL: URL? {
            (tableFiles ?? [])
                .sorted()
                .lazy
                .compactMap { $0.url }
                .first
        }

        var backglassURL: URL? {
            (b2sFiles ?? [])
                .sorted()
                .lazy
                .compactMap { $0.url }
                .first
        }

        var title: String {
            if let manufacturer, let year {
                "\(name) (\(manufacturer) \(year))"
            } else {
                name
            }
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum State {
        case idle
        case loading(Task<[String: Entry], Error>)
        case loaded([String: Entry])
    }

    private var state = State.idle

    public init() {
    }

    private func contents() async throws -> [String: Entry] {
        switch state {
        case .idle:
            let task = Task {
                let (data, _) = try await URLSession.shared.data(from: url)
                do {
                    let entries = try JSONDecoder().decode([Entry].self, from: data)
                    return Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
                } catch {
                    print(error)
                    throw error
                }
            }
            self.state = .loading(task)
            let contents = try await task.value
            self.state = .loaded(contents)
            return contents
        case .loading(let task):
            return try await task.value
        case .loaded(let contents):
            return contents
        }
    }

    public func load() async throws {
        _ = try await contents()
    }

    public func find(_ string: String) async throws -> [Entry] {
        let contents = try await contents()

        return contents
            .values
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
            }
    }

    public func find(id: String) async throws -> Entry? {
        let contents = try await contents()
        return contents[id]
    }

}
