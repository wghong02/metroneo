import Foundation
import SwiftData

/// Row counts + connection state, ported from `getDatabaseStats`.
public struct DatabaseStats: Equatable {
    public var taskCount: Int
    public var subTaskCount: Int
    public var eventCount: Int
    public var schemaVersion: Int
    public var isClosed: Bool
}

/// Errors thrown by ``SwiftDataDatabase``.
public enum MetroneoError: Error, Equatable {
    case validation(String)
    case database(String)
}

/// SwiftData-backed persistence for tasks (+ subtasks), events, and admin
/// operations (FUNCTIONALITY.md §3). Persists the ``StoredTask`` / ``StoredSubTask``
/// / ``StoredEvent`` models and maps them to/from the domain value types.
///
/// Save semantics: `saveTasks` replaces the entire task + subtask set, preserving
/// each incoming id so references stay stable.
public final class SwiftDataDatabase {
    private let container: ModelContainer
    private let context: ModelContext

    /// - Parameter inMemory: when true, uses an in-memory store (previews/tests).
    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(
                for: StoredTask.self, StoredSubTask.self, StoredEvent.self,
                configurations: config
            )
        } catch {
            throw MetroneoError.database("Failed to load store: \(error)")
        }
        context = ModelContext(container)
    }

    public func reset() throws {
        try context.delete(model: StoredSubTask.self)
        try context.delete(model: StoredTask.self)
        try context.delete(model: StoredEvent.self)
        try context.save()
    }

    public func stats() -> DatabaseStats {
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        }
        return DatabaseStats(
            taskCount: count(StoredTask.self),
            subTaskCount: count(StoredSubTask.self),
            eventCount: count(StoredEvent.self),
            schemaVersion: 1,
            isClosed: false
        )
    }

    // MARK: - Tasks

    public func loadTasks() throws -> [Task] {
        let descriptor = FetchDescriptor<StoredTask>(
            sortBy: [SortDescriptor(\.createDate, order: .reverse)]
        )
        return try context.fetch(descriptor).map(task(from:))
    }

    public func saveTasks(_ tasks: [Task]) throws {
        // Full replace, preserving each incoming id.
        try reset()
        for task in tasks {
            let row = StoredTask(
                taskID: task.id ?? UUID().uuidString,
                title: task.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : task.title,
                notes: task.notes,
                deadline: task.deadline,
                priorityRating: task.priorityRating,
                performanceRating: task.performanceRating,
                completedAt: task.completedAt,
                createDate: task.createDate,
                frequencyPattern: task.frequencyPattern,
                frequencyCount: task.frequencyCount,
                recurring: task.recurring,
                types: task.types ?? [],
                estimatedDuration: task.estimatedDuration,
                actualDuration: task.actualDuration,
                performanceNotes: task.performanceNotes
            )
            context.insert(row)
            for (index, sub) in task.subTasks.enumerated() {
                let subRow = StoredSubTask(
                    subTaskID: sub.id ?? UUID().uuidString,
                    title: sub.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Subtask" : sub.title,
                    notes: sub.notes,
                    deadline: sub.deadline,
                    priorityRating: sub.priorityRating,
                    performanceRating: sub.performanceRating,
                    completedAt: sub.completedAt,
                    orderIndex: index
                )
                subRow.parentTask = row
                context.insert(subRow)
            }
        }
        try context.save()
    }

    // MARK: - Events

    public func loadEvents() throws -> [Event] {
        let descriptor = FetchDescriptor<StoredEvent>(
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.startTime), SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor).map(event(from:))
    }

    public func saveEvent(_ event: Event) throws {
        guard !event.title.isEmpty else {
            throw MetroneoError.validation("Event title is required")
        }
        let row = try eventRow(id: event.id) ?? {
            let new = StoredEvent(
                eventID: event.id, date: event.date, title: event.title, notes: event.notes,
                allDay: event.allDay, startTime: event.startTime, endTime: event.endTime
            )
            context.insert(new)
            return new
        }()
        row.date = event.date
        row.title = event.title
        row.notes = event.notes
        row.allDay = event.allDay
        row.startTime = event.startTime
        row.endTime = event.endTime
        try context.save()
    }

    public func deleteEvent(id: String) throws {
        if let row = try eventRow(id: id) {
            context.delete(row)
            try context.save()
        }
    }

    // MARK: - Row mapping

    private func eventRow(id: String) throws -> StoredEvent? {
        var descriptor = FetchDescriptor<StoredEvent>(predicate: #Predicate<StoredEvent> { $0.eventID == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func task(from row: StoredTask) -> Task {
        Task(
            id: row.taskID,
            title: row.title,
            notes: row.notes,
            deadline: row.deadline,
            priorityRating: row.priorityRating,
            performanceRating: row.performanceRating,
            completedAt: row.completedAt,
            createDate: row.createDate,
            frequencyPattern: row.frequencyPattern,
            frequencyCount: row.frequencyCount,
            recurring: row.recurring,
            types: row.types.isEmpty ? nil : row.types,
            estimatedDuration: row.estimatedDuration,
            actualDuration: row.actualDuration,
            performanceNotes: row.performanceNotes,
            subTasks: row.subTasks.sorted { $0.orderIndex < $1.orderIndex }.map(subTask(from:))
        )
    }

    private func subTask(from row: StoredSubTask) -> SubTask {
        SubTask(
            id: row.subTaskID,
            title: row.title,
            notes: row.notes,
            deadline: row.deadline,
            priorityRating: row.priorityRating,
            performanceRating: row.performanceRating,
            completedAt: row.completedAt,
            parentTaskId: row.parentTask?.taskID,
            order: row.orderIndex
        )
    }

    private func event(from row: StoredEvent) -> Event {
        Event(
            id: row.eventID,
            date: row.date,
            title: row.title,
            notes: row.notes,
            allDay: row.allDay,
            startTime: row.startTime,
            endTime: row.endTime
        )
    }
}
