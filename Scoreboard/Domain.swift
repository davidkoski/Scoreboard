//
//  Domain.swift
//  Scoreboard
//
//  Created by David Koski on 8/3/25.
//

import Foundation

public struct Day: Codable, Hashable, Sendable, CodingKeyRepresentable, CodingKey,
    CustomStringConvertible, Comparable
{
    public let value: Int

    public var description: String {
        "\(month)/\(day)/\(year)"
    }

    public var date: Date {
        DateComponents(calendar: Calendar.current, year: year, month: month, day: day).date!
    }

    public var year: Int {
        value / 10000
    }

    public var month: Int {
        (value % 10000) / 100
    }

    public var day: Int {
        value % 100
    }

    public init?<T>(codingKey: T) where T: CodingKey {
        guard let value = codingKey.intValue else { return nil }
        self.value = value
    }

    public init?(stringValue: String) {
        guard let value = Int(stringValue) else { return nil }
        self.value = value
    }

    public init?(intValue: Int) {
        self.value = intValue
    }

    public init(_ date: Date) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        self.value = year * 100 * 100 + month * 100 + day
    }

    public var codingKey: any CodingKey { self }
    public var stringValue: String { value.description }
    public var intValue: Int? { value }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        lhs.value < rhs.value
    }
}

public struct Seconds: Codable, Hashable, Sendable, CustomStringConvertible, Comparable,
    AdditiveArithmetic, ExpressibleByIntegerLiteral
{

    public static var zero = Seconds(0)

    public let value: Int

    public var description: String {
        let seconds = value % 60
        let minutes = (value / 60)

        if minutes == 0 {
            return "\(seconds) s"
        } else {
            return
                "\(minutes.formatted(.number.precision(.integerLength(2..<10)))) m \(seconds.formatted(.number.precision(.integerLength(2)))) s"
        }
    }

    public init(_ value: Int) {
        self.value = value
    }

    public init(integerLiteral value: Int) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }

    public static func < (lhs: Seconds, rhs: Seconds) -> Bool {
        lhs.value < rhs.value
    }

    public static func + (lhs: Seconds, rhs: Seconds) -> Seconds {
        .init(lhs.value + rhs.value)
    }

    public static func - (lhs: Seconds, rhs: Seconds) -> Seconds {
        .init(lhs.value - rhs.value)
    }
}
