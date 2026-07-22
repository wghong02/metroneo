import Foundation

/// In-memory ``TaskDatabase`` for tests and previews. Matches the save
/// semantics of the production store: `saveTasks` clears and re-inserts
/// everything, assigning sequential string ids to tasks and subtasks.
public final class InMemoryDatabase: TaskDatabase {
    private var tasks: [Task] = []
    private var events: [String: Event] = [:]
    private var nextTaskID = 1
    private var nextSubTaskID = 1

    public init() {}

    public func initialize() throws {}

    public func reset() throws {
        tasks = []
        events = [:]
        nextTaskID = 1
        nextSubTaskID = 1
    }

    public func stats() -> DatabaseStats {
        DatabaseStats(
            taskCount: tasks.count,
            subTaskCount: tasks.reduce(0) { $0 + $1.subTasks.count },
            eventCount: events.count,
            settingCount: 0,
            schemaVersion: 1,
            isClosed: false
        )
    }

    // MARK: Tasks

    public func loadTasks() throws -> [Task] {
        // Newest first, by createDate.
        tasks.sorted { $0.createDate > $1.createDate }
    }

    public func saveTasks(_ newTasks: [Task]) throws {
        var stored: [Task] = []
        for var task in newTasks {
            let taskID = String(nextTaskID); nextTaskID += 1
            task.id = taskID
            task.title = task.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : task.title
            task.subTasks = task.subTasks.enumerated().map { index, sub in
                var s = sub
                s.id = String(nextSubTaskID); nextSubTaskID += 1
                s.parentTaskId = taskID
                s.order = index
                if s.title.trimmingCharacters(in: .whitespaces).isEmpty { s.title = "New Subtask" }
                return s
            }
            stored.append(task)
        }
        tasks = stored
    }

    // MARK: Events

    public func loadEvents() throws -> [Event] {
        events.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            let s0 = $0.startTime ?? .distantPast, s1 = $1.startTime ?? .distantPast
            if s0 != s1 { return s0 < s1 }
            return $0.title < $1.title
        }
    }

    public func saveEvent(_ event: Event) throws {
        guard !event.title.isEmpty else {
            throw MetroneoError.validation("Event title is required")
        }
        events[event.id] = event
    }

    public func deleteEvent(id: String) throws { events.removeValue(forKey: id) }

    public func event(id: String) throws -> Event? { events[id] }

    public func events(forDate date: Date) throws -> [Event] {
        let calendar = Calendar.current
        return try loadEvents().filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

public enum MetroneoError: Error, Equatable {
    case validation(String)
    case database(String)
}
