import Foundation

/// Pure, platform-independent time helpers (FUNCTIONALITY.md §4.2, §5.2).
/// Times are modeled as 24-hour `"HH:mm"` strings throughout.
public enum TimeUtilities {

    /// Converts a 24-hour `"HH:mm"` string to a 12-hour display string with meridiem.
    ///
    /// - Examples: `"00:00"` → `"12:00 AM"`, `"09:30"` → `"9:30 AM"`,
    ///   `"13:05"` → `"1:05 PM"`, `"23:30"` → `"11:30 PM"`.
    /// - Returns the input unchanged if it is not a parseable `"HH:mm"` string.
    public static func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]) else { return time }
        let minutes = String(parts[1])
        let ampm = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):\(minutes) \(ampm)"
    }

    /// Every 30 minutes across a full day: 48 zero-padded `"HH:mm"` options
    /// from `"00:00"` through `"23:30"`.
    public static func generateTimeOptions() -> [String] {
        var times: [String] = []
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: 30) {
                times.append(String(format: "%02d:%02d", hour, minute))
            }
        }
        return times
    }

    /// Formats a `Date` to the `"yyyy-MM-dd"` key used to group tasks, matching the
    /// calendar `dateString` from the original app. Uses a fixed POSIX calendar so
    /// the key is stable regardless of locale.
    public static func dateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
