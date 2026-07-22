import Foundation

/// A date-anchored calendar entry (FUNCTIONALITY.md §2.4).
public struct Event: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    /// The day this event belongs to (normalized to local start-of-day).
    public var date: Date
    public var title: String
    public var notes: String?
    public var allDay: Bool
    /// Start/end times, anchored to ``date``'s day (see `EventService`).
    public var startTime: Date?
    public var endTime: Date?

    public init(
        id: String = Event.makeID(),
        date: Date,
        title: String,
        notes: String? = nil,
        allDay: Bool = false,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.notes = notes
        self.allDay = allDay
        self.startTime = startTime
        self.endTime = endTime
    }

    /// Generates an id like the app's `event-{timestamp}-{rand}`.
    public static func makeID(date: Date = Date()) -> String {
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let rand = Int.random(in: 0..<1_000_000)
        return "event-\(millis)-\(rand)"
    }
}

/// Events grouped by local start-of-day.
public typealias EventMap = [Date: [Event]]
