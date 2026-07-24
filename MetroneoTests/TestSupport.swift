import Foundation

/// Shared test helpers.

/// Local start-of-day `Date` for a `"YYYY-MM-DD"` key.
func day(_ key: String) -> Date {
    let p = key.split(separator: "-").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
}
