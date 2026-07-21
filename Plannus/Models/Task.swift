import Foundation

/// Sentinel stored in `completedAt` when a task/subtask is not complete.
/// Matches the `"na"` sentinel used throughout the original app.
public let kNotCompleted = "na"

/// How often a recurring task repeats (FUNCTIONALITY.md §2.2).
public enum FrequencyPattern: String, Codable, CaseIterable, Sendable {
    case daily, weekly, monthly, yearly, custom, none
}

/// A subtask belonging to a ``Task`` (FUNCTIONALITY.md §2.3).
public struct SubTask: Codable, Identifiable, Equatable, Hashable {
    public var id: String?
    public var title: String
    public var notes: String?
    public var deadline: String
    public var priorityRating: Int
    public var performanceRating: Int
    public var completedAt: String
    public var parentTaskId: String?
    public var order: Int

    public init(
        id: String? = nil,
        title: String,
        notes: String? = nil,
        deadline: String = "",
        priorityRating: Int = 0,
        performanceRating: Int = 0,
        completedAt: String = kNotCompleted,
        parentTaskId: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.deadline = deadline
        self.priorityRating = priorityRating
        self.performanceRating = performanceRating
        self.completedAt = completedAt
        self.parentTaskId = parentTaskId
        self.order = order
    }

    public var isCompleted: Bool { completedAt != kNotCompleted }
}

/// The core productivity model (FUNCTIONALITY.md §2.2).
public struct Task: Codable, Identifiable, Equatable, Hashable {
    public var id: String?
    public var title: String
    public var notes: String?
    /// `"YYYY-MM-DDTHH:mm:ss"`. Defaults to `T23:59:59` when no time is given.
    public var deadline: String
    /// 0–100, default 50.
    public var priorityRating: Int
    /// 0–100, default 50.
    public var performanceRating: Int
    /// `"YYYY-MM-DD"` when complete, else ``kNotCompleted``.
    public var completedAt: String
    /// `"YYYY-MM-DD"` (local). Required.
    public var createDate: String
    public var frequencyPattern: FrequencyPattern
    public var frequencyCount: Int
    public var recurring: Bool
    public var types: [String]?
    public var estimatedDuration: Int?
    public var actualDuration: Int?
    public var performanceNotes: String?
    public var subTasks: [SubTask]

    public init(
        id: String? = nil,
        title: String,
        notes: String? = nil,
        deadline: String,
        priorityRating: Int = 50,
        performanceRating: Int = 50,
        completedAt: String = kNotCompleted,
        createDate: String,
        frequencyPattern: FrequencyPattern = .none,
        frequencyCount: Int = 0,
        recurring: Bool = false,
        types: [String]? = nil,
        estimatedDuration: Int? = nil,
        actualDuration: Int? = nil,
        performanceNotes: String? = nil,
        subTasks: [SubTask] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.deadline = deadline
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

    public var isCompleted: Bool { completedAt != kNotCompleted }

    /// Composes a deadline string from a date key and optional `"HH:mm"` time,
    /// defaulting to end-of-day (`T23:59:59`) — ports the New Task modal logic.
    public static func composeDeadline(date: String, time: String?) -> String {
        if let time, !time.isEmpty { return "\(date)T\(time):00" }
        return "\(date)T23:59:59"
    }
}
