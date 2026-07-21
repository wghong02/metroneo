import Foundation

/// A scheduled task, tied to a calendar date via ``TaskMap``.
///
/// Mirrors the `Task` model from the original app (FUNCTIONALITY.md §2.1).
public struct Task: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier — a millisecond-timestamp string generated at creation,
    /// matching the JS `Date.now().toString()` behavior.
    public var id: String

    /// The task description. Required — an empty title is a no-op on save.
    public var title: String

    /// 24-hour clock time in `"HH:mm"` format (e.g. `"09:00"`, `"14:30"`).
    public var time: String

    /// Optional free-text notes.
    public var notes: String?

    public init(id: String, title: String, time: String, notes: String? = nil) {
        self.id = id
        self.title = title
        self.time = time
        self.notes = notes
    }

    /// Generates an identifier the way the source app does: whole milliseconds
    /// since the Unix epoch, rendered as a string.
    public static func makeID(date: Date = Date()) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000).rounded()))
    }
}

/// Tasks grouped by calendar date string in `"YYYY-MM-DD"` format
/// (FUNCTIONALITY.md §2.2).
public typealias TaskMap = [String: [Task]]
