import Foundation

/// Pure date/time helpers ported from `utils/functions.ts` and `utils/apis.ts`
/// (FUNCTIONALITY.md §5). Time-of-day is modeled as 24-hour `"HH:mm"` strings and
/// dates as `"YYYY-MM-DD"` keys.
public enum DateTimeUtilities {

    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    /// 24-hour `"HH:mm"` → 12-hour `"h:mm AM/PM"`. Ports `formatTime`.
    /// Returns the input unchanged if unparseable.
    public static func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, let hour = Int(parts[0]) else { return time }
        let minutes = String(parts[1])
        let ampm = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):\(minutes) \(ampm)"
    }

    /// `"YYYY-MM-DD"` local key for a `Date` (the app's `en-CA` format).
    public static func dateKey(for date: Date) -> String {
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Today's `"YYYY-MM-DD"` key.
    public static func todayKey() -> String { dateKey(for: Date()) }

    /// Parses a `"YYYY-MM-DD"` key to a `Date` at local midnight.
    public static func date(fromKey key: String) -> Date? {
        let datePart = key.split(separator: "T").first.map(String.init) ?? key
        let comps = datePart.split(separator: "-").compactMap { Int($0) }
        guard comps.count == 3 else { return nil }
        var dc = DateComponents()
        dc.year = comps[0]; dc.month = comps[1]; dc.day = comps[2]
        return gregorian.date(from: dc)
    }

    /// Localized deadline display. If the deadline carries a time part, returns
    /// `"<date> at <formatTime(HH:mm)>"`. Ports `formatDeadline`.
    public static func formatDeadline(_ deadline: String, locale: Locale = .current) -> String {
        let segments = deadline.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
        let datePart = String(segments.first ?? "")
        let dateDisplay = localizedDate(fromKey: datePart, locale: locale)
        if segments.count > 1 {
            let timeParts = segments[1].split(separator: ":")
            if timeParts.count >= 2 {
                let hhmm = "\(timeParts[0]):\(timeParts[1])"
                return "\(dateDisplay) at \(formatTime(hhmm))"
            }
        }
        return dateDisplay
    }

    /// Localized short date for a `"YYYY-MM-DD"` key (like JS `toLocaleDateString`).
    public static func localizedDate(fromKey key: String, locale: Locale = .current) -> String {
        guard let d = date(fromKey: key) else { return key }
        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: d)
    }

    /// Incomplete tasks whose deadline **date** equals `targetDate`.
    /// Ports `getIncompleteTasksForDate` (FUNCTIONALITY.md §5).
    public static func incompleteTasks(_ tasks: [Task], forDate targetDate: String) -> [Task] {
        tasks.filter { task in
            guard task.completedAt == kNotCompleted else { return false }
            let deadlineDate = task.deadline.split(separator: "T").first.map(String.init) ?? task.deadline
            return deadlineDate == targetDate
        }
    }

    // MARK: - Picker option generators

    /// Hour labels `"00"`…`"23"`.
    public static func hourOptions() -> [String] { (0..<24).map { String(format: "%02d", $0) } }

    /// Minute labels `"00"`…`"59"`.
    public static func minuteOptions() -> [String] { (0..<60).map { String(format: "%02d", $0) } }

    /// Year labels for the date wheel: current year ±10.
    public static func yearOptions(around date: Date = Date()) -> [String] {
        let year = gregorian.component(.year, from: date)
        return ((year - 10)...(year + 10)).map { String($0) }
    }
}
