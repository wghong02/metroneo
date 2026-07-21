import Foundation

/// A minimal string key/value store, mirroring the surface of React Native's
/// `AsyncStorage`. Backs the persistence used by ``TaskStore`` and ``TodoStore``.
public protocol KeyValueStore {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    func removeValue(forKey key: String)
}

/// `UserDefaults`-backed store — the iOS analogue of `AsyncStorage`.
public struct UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    public func set(_ value: String, forKey key: String) { defaults.set(value, forKey: key) }
    public func removeValue(forKey key: String) { defaults.removeObject(forKey: key) }
}

/// In-memory store, useful for tests and previews.
public final class InMemoryStore: KeyValueStore {
    private var storage: [String: String]

    public init(_ storage: [String: String] = [:]) { self.storage = storage }

    public func string(forKey key: String) -> String? { storage[key] }
    public func set(_ value: String, forKey key: String) { storage[key] = value }
    public func removeValue(forKey key: String) { storage.removeValue(forKey: key) }
}
