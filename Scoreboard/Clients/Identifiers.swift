//
//  Identifiers.swift
//  Scoreboard
//
//  Created by David Koski on 10/19/24.
//

import Foundation

/// Identifier for ``PinballDB``
///
/// This is the identifier for the table in the global pinball spreadsheet.  Two table that have the same
/// ``PinballDBId`` are variations on the same general table and might be considered equivalent.
public struct WebTableId: Codable, Hashable, Sendable, CodingKeyRepresentable, CodingKey,
    CustomStringConvertible
{
    public let id: String

    public var description: String { id }

    public init?<T>(codingKey: T) where T: CodingKey {
        self.id = codingKey.stringValue
    }

    public init?(stringValue: String) {
        self.id = stringValue
    }

    public init?(intValue: Int) {
        self.id = intValue.description
    }

    public var codingKey: any CodingKey { self }
    public var stringValue: String { id }
    public var intValue: Int? { nil }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }
}

/// Identifier for ``PinupPopper``.
///
/// This is the primary key (numeric) for the database in the cabinet.  There will be a single table with this identifier.
public struct CabinetTableId: Codable, Hashable, Sendable, CodingKeyRepresentable, CodingKey {
    public let id: String

    public var description: String { id }

    public init?<T>(codingKey: T) where T: CodingKey {
        self.id = codingKey.stringValue
    }

    public init?(stringValue: String) {
        self.id = stringValue
    }

    public init?(intValue: Int) {
        self.id = intValue.description
    }

    public var codingKey: any CodingKey { self }
    public var stringValue: String { id }
    public var intValue: Int? { nil }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) {
            self.id = v.description
        } else {
            self.id = try container.decode(String.self)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }
}

public struct ScoreId: Codable, Hashable, Sendable, Identifiable, Comparable,
    CustomStringConvertible
{
    public let name: String
    public var offset: Int

    public var id: ScoreId { self }

    internal init(name: String, offset: Int) {
        self.name = name
        self.offset = offset
    }

    public init(_ table: VPinStudio.TableDetails) {
        switch table.highscoreType {
        case .nvram:
            self.name = table.rom
            self.offset = table.nvOffset
        case .em:
            self.name = table.hsFileName ?? table.rom
            self.offset = 0
        case .vpreg:
            self.name = table.rom
            self.offset = 0
        case .none, .na:
            self.name = table.webId.id
            self.offset = -1
        }
    }

    public var isManual: Bool { offset == -1 }

    public static func < (lhs: ScoreId, rhs: ScoreId) -> Bool {
        if lhs.name == rhs.name {
            lhs.offset < rhs.offset
        } else {
            lhs.name.lowercased() < rhs.name.lowercased()
        }
    }

    public var description: String {
        if offset == 0 || offset == -1 {
            name
        } else {
            "\(name):\(offset)"
        }
    }

    func withOffset(_ offset: Int) -> ScoreId {
        var new = self
        new.offset = offset
        return new
    }
}
