import Foundation
import Combine

/// Observable store for date-keyed scheduled tasks.
///
/// Ports `utils/taskStorage.ts` plus the save/delete semantics of `CalendarScreen`
/// (FUNCTIONALITY.md §3–4). Persists a JSON-serialized ``TaskMap`` under `"task"`.
public final class TaskStore: ObservableObject {

    /// Storage key used for the scheduled-task map.
    public static let storageKey = "task"

    @Published public private(set) var tasks: TaskMap = [:]

    private let store: KeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(store: KeyValueStore = UserDefaultsStore()) {
        self.store = store
        self.tasks = load()
    }

    /// Tasks for a given date key, or an empty list.
    public func tasks(on date: String) -> [Task] { tasks[date] ?? [] }

    // MARK: - Persistence (ports utils/taskStorage.ts)

    /// Reads and decodes the stored map; returns an empty map when nothing is
    /// stored or the payload cannot be decoded. Ports `loadTasks`.
    private func load() -> TaskMap {
        guard
            let json = store.string(forKey: Self.storageKey),
            let data = json.data(using: .utf8),
            let map = try? decoder.decode(TaskMap.self, from: data)
        else { return [:] }
        return map
    }

    /// Encodes and writes the entire map back to storage. Ports `saveTasks`.
    private func persist() {
        guard
            let data = try? encoder.encode(tasks),
            let json = String(data: data, encoding: .utf8)
        else { return }
        store.set(json, forKey: Self.storageKey)
    }

    // MARK: - Mutations (port CalendarScreen handlers)

    /// Adds or edits a task for the given date, then re-sorts that date's list by
    /// time. Ports `handleSaveTask` (FUNCTIONALITY.md §4.1):
    ///
    /// - An empty/whitespace-only `title` is a no-op.
    /// - When `editIndex` is non-nil, replaces the task at that index, preserving `id`.
    /// - Otherwise appends a new task with a freshly generated `id`.
    /// - The date's list is sorted ascending by `time` (lexicographic on `"HH:mm"`).
    public func saveTask(
        date: String,
        title: String,
        time: String,
        notes: String,
        editIndex: Int? = nil,
        now: Date = Date()
    ) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var items = tasks[date] ?? []
        if let editIndex, items.indices.contains(editIndex) {
            let existing = items[editIndex]
            items[editIndex] = Task(id: existing.id, title: title, time: time, notes: notes)
        } else {
            items.append(Task(id: Task.makeID(date: now), title: title, time: time, notes: notes))
        }
        items.sort { $0.time < $1.time }

        tasks[date] = items
        persist()
    }

    /// Removes the task at `index` within `date`'s list and persists. A missing date
    /// or out-of-range index is a no-op. Ports `deleteTask`.
    public func deleteTask(date: String, index: Int) {
        guard var items = tasks[date], items.indices.contains(index) else { return }
        items.remove(at: index)
        tasks[date] = items
        persist()
    }
}
