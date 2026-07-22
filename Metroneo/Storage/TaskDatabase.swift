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

/// Persistence abstraction for tasks (+ subtasks), events, and admin operations
/// (FUNCTIONALITY.md §3).
///
/// Save semantics: `saveTasks` replaces the entire task+subtask set; the store
/// assigns string ids on insert.
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
    func events(forDate date: Date) throws -> [Event]
}
