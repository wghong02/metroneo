import Foundation
import Combine

/// Observable task cache backed by a ``SwiftDataDatabase`` (FUNCTIONALITY.md §4.1).
///
/// Every mutation writes through to the database immediately — there is no manual
/// save step. Each call edits the in-memory working copy and then persists it. Ids
/// are assigned once (when a task/subtask is first added) and never change, so
/// captured ids stay valid across edits and saves.
public final class TaskService: ObservableObject {
    @Published public private(set) var tasks: [Task] = []

    private let db: SwiftDataDatabase

    public init(db: SwiftDataDatabase) {
        self.db = db
    }

    // MARK: - Loading

    @discardableResult
    public func loadTasks() -> [Task] {
        tasks = (try? db.loadTasks()) ?? []
        return tasks
    }

    // MARK: - Mutations (each persists immediately)

    public func addTask(_ task: Task) {
        tasks.append(normalized(task))
        persist()
    }

    public func updateTask(_ updated: Task) {
        let task = normalized(updated)
        tasks = tasks.map { $0.id == task.id ? task : $0 }
        persist()
    }

    public func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    public func completeTask(id: String) { mutate(id) { $0.completedAt = Date() } }

    public func uncompleteTask(id: String) { mutate(id) { $0.completedAt = nil } }

    /// Sets performance rating (+ optional notes). Used for both completing and
    /// editing an already-completed task's rating.
    public func updateTaskPerformance(id: String, performance: Int, notes: String? = nil) {
        mutate(id) { $0.performanceRating = performance; $0.performanceNotes = notes }
    }

    /// Toggles a subtask's completion (now ↔ nil) within its parent.
    public func toggleSubTask(taskId: String, subTaskId: String) {
        mutate(taskId) { task in
            task.subTasks = task.subTasks.map { sub in
                guard sub.id == subTaskId else { return sub }
                var s = sub
                s.completedAt = sub.isCompleted ? nil : Date()
                return s
            }
        }
    }

    // MARK: - Helpers

    private func mutate(_ id: String, _ change: (inout Task) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
        persist()
    }

    /// Writes the working copy to the store, then reloads so persisted ids/order
    /// are reflected. On a write failure the optimistic in-memory copy is kept.
    private func persist() {
        do {
            try db.saveTasks(tasks)
        } catch {
            Log.taskError("Failed to save tasks: \(error)")
            return
        }
        tasks = (try? db.loadTasks()) ?? tasks
    }

    /// Assigns stable ids to a new task/subtasks and normalizes titles and order.
    /// Existing ids are left untouched.
    private func normalized(_ task: Task) -> Task {
        var t = task
        if t.id == nil { t.id = UUID().uuidString }
        t.title = t.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : t.title
        t.notes = t.notes?.trimmingCharacters(in: .whitespaces)
        let parentID = t.id
        t.subTasks = t.subTasks.enumerated().map { index, sub in
            var s = sub
            if s.id == nil { s.id = UUID().uuidString }
            s.parentTaskId = parentID
            s.order = index
            if s.title.trimmingCharacters(in: .whitespaces).isEmpty { s.title = "New Subtask" }
            return s
        }
        return t
    }
}
