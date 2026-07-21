import Foundation

/// A date-anchored calendar entry (FUNCTIONALITY.md §2.4).
public struct Event: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    /// `"YYYY-MM-DD"`.
    public var date: String
    public var title: String
    public var notes: String?
    public var allDay: Bool
    /// `"HH:mm"`.
    public var startTime: String?
    public var endTime: String?

    public init(
        id: String = Event.makeID(),
        date: String,
        title: String,
        notes: String? = nil,
        allDay: Bool = false,
        startTime: String? = nil,
        endTime: String? = nil
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

/// Events grouped by `"YYYY-MM-DD"` date key.
public typealias EventMap = [String: [Event]]
