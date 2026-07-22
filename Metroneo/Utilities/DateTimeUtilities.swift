import Foundation

/// Pure date/time helpers (FUNCTIONALITY.md §5). Dates are modeled as `Date`;
/// time-of-day for events is still carried as 24-hour `"HH:mm"` strings.
public enum DateTimeUtilities {

    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    // MARK: - Date construction

    /// Local start-of-day for a date.
    public static func startOfDay(_ date: Date) -> Date { gregorian.startOfDay(for: date) }

    /// Today at the given time-of-day — a default seed for time pickers.
    public static func time(hour: Int, minute: Int) -> Date {
        gregorian.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// End-of-day (`23:59:59`) for a day. This is the deadline sentinel used when
    /// no explicit time is set.
    public static func endOfDay(_ day: Date) -> Date {
        dateBySetting(day: day, hour: 23, minute: 59, second: 59)
    }

    /// Combines a day's calendar date with a time-of-day into a single `Date`.
    public static func combine(day: Date, time: Date) -> Date {
        let t = gregorian.dateComponents([.hour, .minute], from: time)
        return dateBySetting(day: day, hour: t.hour ?? 0, minute: t.minute ?? 0, second: 0)
    }

    /// Whether a deadline carries an explicit time (i.e. is not the `23:59:59`
    /// end-of-day sentinel).
    public static func hasExplicitTime(_ deadline: Date) -> Bool {
        let c = gregorian.dateComponents([.hour, .minute, .second], from: deadline)
        return !(c.hour == 23 && c.minute == 59 && c.second == 59)
    }

    // MARK: - Display

    /// Localized short date (like JS `toLocaleDateString`).
    public static func shortDate(_ date: Date, locale: Locale = .current) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: date)
    }

    /// Localized deadline display. Appends `"at <time>"` when the deadline carries
    /// an explicit (non-end-of-day) time.
    public static func formatDeadline(_ deadline: Date, locale: Locale = .current) -> String {
        let dateDisplay = shortDate(deadline, locale: locale)
        guard hasExplicitTime(deadline) else { return dateDisplay }
        let tf = DateFormatter()
        tf.locale = locale
        tf.dateStyle = .none
        tf.timeStyle = .short
        return "\(dateDisplay) at \(tf.string(from: deadline))"
    }

    // MARK: - Queries

    /// Incomplete tasks whose deadline falls on the same day as `targetDate`
    /// (FUNCTIONALITY.md §5).
    public static func incompleteTasks(_ tasks: [Task], forDate targetDate: Date) -> [Task] {
        tasks.filter { task in
            guard task.completedAt == nil else { return false }
            return gregorian.isDate(task.deadline, inSameDayAs: targetDate)
        }
    }

    // MARK: - Helpers

    private static func dateBySetting(day: Date, hour: Int, minute: Int, second: Int) -> Date {
        let d = gregorian.dateComponents([.year, .month, .day], from: day)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = hour; c.minute = minute; c.second = second
        return gregorian.date(from: c) ?? day
    }
}
