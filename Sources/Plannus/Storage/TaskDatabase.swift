import Foundation

/// Row counts + connection state, ported from `getDatabaseStats`.
public struct DatabaseStats: Equatable {
    public var taskCount: Int
    public var subTaskCount: Int
    public var eventCount: Int
    public var settingCount: Int
    public var schemaVersion: Int
    public var isClosed: Bool
}

/// Persistence abstraction covering the operations from `utils/taskDatabase.ts`,
/// `utils/eventDatabase.ts`, and `utils/database.ts` (FUNCTIONALITY.md §3).
///
/// Save semantics preserve the original app's behavior: `saveTasks` replaces the
/// entire task+subtask set; the store assigns integer-derived string ids.
public protocol TaskDatabase: AnyObject {
    // Lifecycle / admin
    func initialize() throws
    func reset() throws
    func stats() -> DatabaseStats

    // Tasks (+ subtasks)
    func loadTasks() throws -> [Task]
    func saveTasks(_ tasks: [Task]) throws

    // Events
    func loadEvents() throws -> [Event]
    func saveEvent(_ event: Event) throws
    func deleteEvent(id: String) throws
    func event(id: String) throws -> Event?
    func events(forDate date: String) throws -> [Event]
}
