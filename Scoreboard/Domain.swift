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
        if value == 0 {
            "-"
        } else {
            "\(month)/\(day)/\(year)"
        }
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

    private static func decode(_ stringValue: String) -> Int? {
        // handle 20260301 or 2026-03-01 or 2026-03-01
        if let value = Int(stringValue) ?? Int(stringValue.replacingOccurrences(of: "-", with: ""))
        {
            return value
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: stringValue) {
                let cal = Calendar.current
                let components = cal.dateComponents([.year, .month, .day], from: date)
                let dateInt = components.year! * 10000 + components.month! * 100 + components.day!
                return dateInt
            }
        }
        return nil
    }

    public init?(stringValue: String) {
        // handle 20260301 or 2026-03-01
        guard let value = Self.decode(stringValue) else { return nil }
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
        do {
            //
            self.value = try container.decode(Int.self)
        } catch {
            if let value = try Self.decode(container.decode(String.self)) {
                self.value = value
            } else {
                throw error
            }
        }
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
