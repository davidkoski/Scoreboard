import Foundation

extension Collection {
    public func set<T: Hashable>() -> Set<T> where Element == T {
        Set(self)
    }

    public func array<T: Hashable>() -> [T] where Element == T {
        Array(self)
    }

    public func dictionary<K: Hashable, V>() -> [K: V] where Element == (K, V) {
        Dictionary(self) { a, b in a }
    }

    public func dictionary<K: Hashable, V>() -> [K: V] where Element == (key: K, value: V) {
        Dictionary(self.map { ($0.key, $0.value) }) { a, b in a }
    }

    public func dictionary<K: Hashable>(by extract: (Element) -> K) -> [K: Element] {
        Dictionary(self.map { (extract($0), $0) }) { a, b in a }
    }

    public func grouping<K: Hashable>(by extract: (Element) -> K) -> [K: [Element]] {
        Dictionary(grouping: self, by: extract)
    }

    public func grouping<K: Hashable>(by extract: (Element) -> K?) -> [K: [Element]] {
        var result = [K: [Element]]()
        for item in self {
            if let k = extract(item) {
                result[k, default: []].append(item)
            }
        }
        return result
    }

    public func grouping<K: Hashable, V>(by extract: (Element) -> K?, transform: (Element) -> V?)
        -> [K: [V]]
    {
        var result = [K: [V]]()
        for item in self {
            if let k = extract(item), let v = transform(item) {
                result[k, default: []].append(v)
            }
        }
        return result
    }
}
