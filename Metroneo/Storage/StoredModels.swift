import Foundation
import SwiftData

/// SwiftData persistence models for the `Metroneo` store. These are the storage
/// mirror of the domain value types (``Task``, ``SubTask``, ``Event``); the
/// database maps between them. Pure Swift throughout — plain `Int`, `Date`,
/// `[String]`, and the ``FrequencyPattern`` enum, no Objective-C.

@Model
final class StoredTask {
    var taskID: String
    var title: String
    var notes: String?
    var deadline: Date
    /// Default keeps this a lightweight SwiftData migration for existing stores.
    var hasDeadlineTime: Bool = false
    var priorityRating: Int
    var performanceRating: Int
    var completedAt: Date?
    var createDate: Date
    var frequencyPattern: FrequencyPattern
    var frequencyCount: Int
    var recurring: Bool
    var types: [String]
    var estimatedDuration: Int?
    var actualDuration: Int?
    var performanceNotes: String?

    @Relationship(deleteRule: .cascade, inverse: \StoredSubTask.parentTask)
    var subTasks: [StoredSubTask]

    init(
        taskID: String,
        title: String,
        notes: String?,
        deadline: Date,
        hasDeadlineTime: Bool,
        priorityRating: Int,
        performanceRating: Int,
        completedAt: Date?,
        createDate: Date,
        frequencyPattern: FrequencyPattern,
        frequencyCount: Int,
        recurring: Bool,
        types: [String],
        estimatedDuration: Int?,
        actualDuration: Int?,
        performanceNotes: String?,
        subTasks: [StoredSubTask] = []
    ) {
        self.taskID = taskID
        self.title = title
        self.notes = notes
        self.deadline = deadline
        self.hasDeadlineTime = hasDeadlineTime
        self.priorityRating = priorityRating
        self.performanceRating = performanceRating
        self.completedAt = completedAt
        self.createDate = createDate
        self.frequencyPattern = frequencyPattern
        self.frequencyCount = frequencyCount
        self.recurring = recurring
        self.types = types
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.performanceNotes = performanceNotes
        self.subTasks = subTasks
    }
}

@Model
final class StoredSubTask {
    var subTaskID: String
    var title: String
    var notes: String?
    var deadline: Date
    var priorityRating: Int
    var performanceRating: Int
    var completedAt: Date?
    var orderIndex: Int
    var parentTask: StoredTask?

    init(
        subTaskID: String,
        title: String,
        notes: String?,
        deadline: Date,
        priorityRating: Int,
        performanceRating: Int,
        completedAt: Date?,
        orderIndex: Int
    ) {
        self.subTaskID = subTaskID
        self.title = title
        self.notes = notes
        self.deadline = deadline
        self.priorityRating = priorityRating
        self.performanceRating = performanceRating
        self.completedAt = completedAt
        self.orderIndex = orderIndex
    }
}

@Model
final class StoredEvent {
    @Attribute(.unique) var eventID: String
    var date: Date
    var title: String
    var notes: String?
    var allDay: Bool
    var startTime: Date?
    var endTime: Date?

    init(
        eventID: String,
        date: Date,
        title: String,
        notes: String?,
        allDay: Bool,
        startTime: Date?,
        endTime: Date?
    ) {
        self.eventID = eventID
        self.date = date
        self.title = title
        self.notes = notes
        self.allDay = allDay
        self.startTime = startTime
        self.endTime = endTime
    }
}
