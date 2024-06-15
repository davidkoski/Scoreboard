//
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation

public struct CountedSet<Element>: Sendable, Equatable where Element: (Hashable & Sendable) {

    private var contents: [Element: Int]
    public private(set) var count: Int

    public init() {
        contents = [:]
        count = 0
    }

    public init<S: Sequence<(Element, Int)>>(keysAndValues: S) {
        contents = Dictionary(uniqueKeysWithValues: keysAndValues)
        count = contents.reduce(0, { $0 + $1.value })
    }

    public init<S: Sequence<(key: Element, value: Int)>>(keysAndValues: S) {
        contents = Dictionary(uniqueKeysWithValues: keysAndValues.map { ($0.key, $0.value) })
        count = contents.reduce(0, { $0 + $1.value })
    }

    public init<S: Sequence<CountedSet<Element>>>(countedSets: S) {
        contents = [:]
        count = 0
        for item in countedSets {
            add(item)
        }
    }

    public init(contents: [Element: Int]) {
        self.contents = contents
        count = contents.reduce(0, { $0 + $1.value })
    }

    public init(items: [Element]) {
        contents = [:]
        count = 0
        for item in items {
            add(item)
        }
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public func contains(_ item: Element) -> Bool {
        (contents[item] ?? 0) > 0
    }

    @discardableResult
    public mutating func remove(_ item: Element, count: Int = 1) -> Bool {
        if let c = contents[item] {
            assert(c >= count)

            self.count -= count

            if c == count {
                contents[item] = nil
                return true
            } else {
                contents[item] = c - count
                return false
            }
        } else {
            fatalError("\(item) not present")
        }
    }

    public mutating func removeAll() {
        contents.removeAll()
        count = 0
    }

    public mutating func add(_ item: Element, count: Int = 1) {
        contents[item, default: 0] += count
        self.count += count
    }

    public mutating func add(_ other: CountedSet<Element>) {
        for (key, count) in other.contents {
            contents[key, default: 0] += count
            self.count += count
        }
    }

    public var asDictionary: [Element: Int] {
        contents
    }

    public var keys: Dictionary<Element, Int>.Keys {
        contents.keys
    }

    public subscript(_ key: Element) -> Int {
        return contents[key, default: 0]
    }

    public func subtracting(_ other: CountedSet<Element>) -> CountedSet<Element> {
        var result = self

        for (key, value) in other.contents {
            result.remove(key, count: value)
        }

        return result
    }

    public func subtracting(_ other: Set<Element>) -> CountedSet<Element> {
        var result = self

        for key in other {
            if let c = result.contents[key] {
                result.count -= c
                result.contents[key] = nil
            }
        }

        return result
    }

    public mutating func subtract(_ other: CountedSet<Element>) {
        for (key, value) in other.contents {
            if let c = contents[key] {
                assert(value <= c)

                if c == value {
                    contents[key] = nil
                } else {
                    contents[key] = c - value
                }
            }
        }
    }

    public mutating func subtract(_ other: Set<Element>) {
        for key in other {
            if let c = self.contents[key] {
                self.count -= c
                self.contents[key] = nil
            }
        }
    }

    public mutating func subtract(_ other: CombinedSet<Element>) {
        for set in other.contents {
            for key in set {
                if let c = self.contents[key] {
                    self.count -= c
                    self.contents[key] = nil
                }
            }
        }
    }

    public func filter(_ isIncluded: (Element) -> Bool) -> CountedSet<Element> {
        CountedSet(keysAndValues: contents.filter { isIncluded($0.key) })
    }

    public func mostFrequent() -> Element? {
        if let max = contents.values.lazy.filter { $0 > 1 }.max() {
            return contents.first { $0.value == max }?.key
        }
        return nil
    }
}

extension CountedSet: Hashable where Element: Hashable {

}

extension CountedSet: Codable where Element: Codable {

}

extension CountedSet: Sequence {

    public func makeIterator() -> Dictionary<Element, Int>.Iterator {
        contents.makeIterator()
    }

}

public struct CombinedSet<T: Hashable & Sendable>: Sendable, Equatable {
    let contents: [Set<T>]

    public init(_ contents: [Set<T>]) {
        self.contents = contents
    }

    public func contains(_ value: T) -> Bool {
        contents.contains { set in
            set.contains(value)
        }
    }
}
