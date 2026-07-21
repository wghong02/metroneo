import Foundation
import Combine

/// Observable store for the standalone flat to-do list (Tasks tab), independent of
/// the calendar's scheduled tasks. Ports `screens/TaskScreen.tsx`
/// (FUNCTIONALITY.md §6). Persists a JSON array of strings under `"@todos_list"`.
public final class TodoStore: ObservableObject {

    /// Storage key used for the simple to-do list.
    public static let storageKey = "@todos_list"

    @Published public private(set) var todos: [String] = []

    private let store: KeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: KeyValueStore = UserDefaultsStore()) {
        self.store = store
        self.todos = load()
    }

    private func load() -> [String] {
        guard
            let json = store.string(forKey: Self.storageKey),
            let data = json.data(using: .utf8),
            let list = try? decoder.decode([String].self, from: data)
        else { return [] }
        return list
    }

    private func persist() {
        guard
            let data = try? encoder.encode(todos),
            let json = String(data: data, encoding: .utf8)
        else { return }
        store.set(json, forKey: Self.storageKey)
    }

    /// Appends a trimmed to-do, ignoring empty/whitespace-only input. Ports `addTodo`.
    public func addTodo(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.append(trimmed)
        persist()
    }

    /// Removes the to-do at `index` (no-op if out of range). Ports `deleteTodo`.
    public func deleteTodo(at index: Int) {
        guard todos.indices.contains(index) else { return }
        todos.remove(at: index)
        persist()
    }

    /// Convenience for SwiftUI `onDelete(perform:)`.
    public func deleteTodos(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where todos.indices.contains(index) {
            todos.remove(at: index)
        }
        persist()
    }
}
