import Foundation

/// How often a recurring task repeats (FUNCTIONALITY.md §2.2).
public enum FrequencyPattern: String, Codable, CaseIterable, Sendable {
    case daily, weekly, monthly, yearly, custom, none
}

/// A subtask belonging to a ``Task`` (FUNCTIONALITY.md §2.3).
public struct SubTask: Codable, Identifiable, Equatable, Hashable {
    public var id: String?
    public var title: String
    public var notes: String?
    public var deadline: Date
    public var priorityRating: Int
    public var performanceRating: Int
    /// Completion instant, or `nil` when not complete.
    public var completedAt: Date?
    public var parentTaskId: String?
    public var order: Int

    public init(
        id: String? = nil,
        title: String,
        notes: String? = nil,
        deadline: Date = Date(),
        priorityRating: Int = 0,
        performanceRating: Int = 0,
        completedAt: Date? = nil,
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

    public var isCompleted: Bool { completedAt != nil }
}

/// The core productivity model (FUNCTIONALITY.md §2.2).
public struct Task: Codable, Identifiable, Equatable, Hashable {
    public var id: String?
    public var title: String
    public var notes: String?
    /// Full deadline instant. A time of `23:59:59` marks an end-of-day deadline
    /// with no explicit time (see ``DateTimeUtilities/hasExplicitTime(_:)``).
    public var deadline: Date
    /// 0–100, default 50.
    public var priorityRating: Int
    /// 0–100, default 50.
    public var performanceRating: Int
    /// Completion instant, or `nil` when not complete.
    public var completedAt: Date?
    public var createDate: Date
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
        deadline: Date,
        priorityRating: Int = 50,
        performanceRating: Int = 50,
        completedAt: Date? = nil,
        createDate: Date = Date(),
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

    public var isCompleted: Bool { completedAt != nil }
}
