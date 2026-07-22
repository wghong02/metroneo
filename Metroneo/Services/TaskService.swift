import Foundation
import Combine

/// Observable task cache backed by a ``TaskDatabase`` (FUNCTIONALITY.md §4.1).
/// Persists by re-saving the whole list (the store replaces all rows).
public final class TaskService: ObservableObject {
    @Published public private(set) var tasks: [Task] = []

    private let db: TaskDatabase

    public init(db: TaskDatabase) {
        self.db = db
    }

    @discardableResult
    public func loadTasks() -> [Task] {
        tasks = (try? db.loadTasks()) ?? []
        return tasks
    }

    public func saveTasks(_ newTasks: [Task]) {
        do {
            try db.saveTasks(newTasks)
            // Reload so callers see DB-assigned ids.
            tasks = (try? db.loadTasks()) ?? newTasks
        } catch {
            print("[TaskService] Error saving tasks:", error)
        }
    }

    public func addTask(_ task: Task) {
        var safe = task
        safe.title = task.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : task.title
        safe.notes = (task.notes ?? "").trimmingCharacters(in: .whitespaces)
        saveTasks(tasks + [safe])
    }

    public func updateTask(_ updated: Task) {
        var safe = updated
        if safe.title.isEmpty { safe.title = "New Task" }
        saveTasks(tasks.map { $0.id == safe.id ? safe : $0 })
    }

    public func deleteTask(id: String) {
        saveTasks(tasks.filter { $0.id != id })
    }

    public func completeTask(id: String) {
        saveTasks(tasks.map { task in
            guard task.id == id else { return task }
            var t = task; t.completedAt = DateTimeUtilities.todayKey(); return t
        })
    }

    public func uncompleteTask(id: String) {
        saveTasks(tasks.map { task in
            guard task.id == id else { return task }
            var t = task; t.completedAt = kNotCompleted; return t
        })
    }

    public func updateTaskPriority(id: String, priority: Int) {
        saveTasks(tasks.map { task in
            guard task.id == id else { return task }
            var t = task; t.priorityRating = priority; return t
        })
    }

    /// Sets performance rating (+ optional notes). Used for both completing and
    /// editing an already-completed task's rating.
    public func updateTaskPerformance(id: String, performance: Int, notes: String? = nil) {
        saveTasks(tasks.map { task in
            guard task.id == id else { return task }
            var t = task; t.performanceRating = performance; t.performanceNotes = notes; return t
        })
    }

    /// Toggles a subtask's completion (today ↔ `"na"`) within its parent.
    public func toggleSubTask(taskId: String, subTaskId: String) {
        saveTasks(tasks.map { task in
            guard task.id == taskId else { return task }
            var t = task
            t.subTasks = task.subTasks.map { sub in
                guard sub.id == subTaskId else { return sub }
                var s = sub
                s.completedAt = sub.isCompleted ? kNotCompleted : DateTimeUtilities.todayKey()
                return s
            }
            return t
        })
    }
}
