import Foundation

/// Time window for performance analytics (FUNCTIONALITY.md §8).
public enum PerformancePeriod: String, CaseIterable {
    case week, month, threeMonths, year, allTime, custom

    public var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .year: return "Year"
        case .allTime: return "All Time"
        case .custom: return "Custom"
        }
    }
}

/// Trend of a data point relative to the previous one.
public enum PerformanceTrend { case up, down, stable }

/// One point in a weekly/monthly performance series.
public struct PerformanceDataPoint: Equatable {
    public var period: String
    public var average: Double
    public var taskCount: Int
    public var trend: PerformanceTrend

    public init(period: String, average: Double, taskCount: Int, trend: PerformanceTrend) {
        self.period = period
        self.average = average
        self.taskCount = taskCount
        self.trend = trend
    }

    public static func == (l: PerformanceDataPoint, r: PerformanceDataPoint) -> Bool {
        l.period == r.period && l.average == r.average && l.taskCount == r.taskCount
    }
}

/// Pure analytics over completed tasks. Ports the calculations in
/// `screens/PerformanceScreen.tsx` (FUNCTIONALITY.md §8).
public enum PerformanceAnalytics {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// Start/end range for a period. `now` and `customStart` are injectable for tests.
    public static func dateRange(
        for period: PerformancePeriod,
        customStart: String? = nil,
        now: Date = Date()
    ) -> (start: Date, end: Date) {
        let cal = calendar
        let end = now
        var start = now
        switch period {
        case .week:        start = cal.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:       start = cal.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths: start = cal.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:        start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:     start = Date(timeIntervalSince1970: 0)
        case .custom:
            if let customStart, let d = DateTimeUtilities.date(fromKey: customStart) {
                start = d
            } else {
                start = cal.date(byAdding: .day, value: -7, to: now) ?? now
            }
        }
        return (start, end)
    }

    /// Completed tasks whose `completedAt` falls within the period.
    public static func filteredTasks(
        _ tasks: [Task],
        period: PerformancePeriod,
        customStart: String? = nil,
        now: Date = Date()
    ) -> [Task] {
        let range = dateRange(for: period, customStart: customStart, now: now)
        return tasks.filter { task in
            guard task.completedAt != kNotCompleted,
                  let d = DateTimeUtilities.date(fromKey: task.completedAt) else { return false }
            return d >= range.start && d <= range.end
        }
    }

    /// Average performance across the given tasks (0 if empty).
    public static func average(_ tasks: [Task]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let sum = tasks.reduce(0) { $0 + $1.performanceRating }
        return Double(sum) / Double(tasks.count)
    }

    /// Last-5-weeks series (oldest → newest), labeled by each week's Monday `MMM d`.
    public static func weeklySeries(_ tasks: [Task], now: Date = Date()) -> [PerformanceDataPoint] {
        let cal = calendar
        var points: [PerformanceDataPoint] = []
        for i in stride(from: 4, through: 0, by: -1) {
            let weekEnd = cal.date(byAdding: .day, value: -i * 7, to: now) ?? now
            let weekStart = cal.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
            let monday = mondayOfWeek(containing: weekStart, cal: cal)
            let weekTasks = tasks.filter { task in
                guard task.completedAt != kNotCompleted,
                      let d = DateTimeUtilities.date(fromKey: task.completedAt) else { return false }
                return d >= weekStart && d <= weekEnd
            }
            points.append(PerformanceDataPoint(
                period: shortLabel(monday, format: "MMM d"),
                average: average(weekTasks),
                taskCount: weekTasks.count,
                trend: .stable
            ))
        }
        return applyTrends(points)
    }

    /// Last-5-months series (oldest → newest), labeled `MMM`.
    public static func monthlySeries(_ tasks: [Task], now: Date = Date()) -> [PerformanceDataPoint] {
        let cal = calendar
        var points: [PerformanceDataPoint] = []
        for i in stride(from: 4, through: 0, by: -1) {
            let monthEnd = cal.date(byAdding: .month, value: -i, to: now) ?? now
            var comps = cal.dateComponents([.year, .month], from: monthEnd)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? monthEnd
            let monthTasks = tasks.filter { task in
                guard task.completedAt != kNotCompleted,
                      let d = DateTimeUtilities.date(fromKey: task.completedAt) else { return false }
                return d >= monthStart && d <= monthEnd
            }
            points.append(PerformanceDataPoint(
                period: shortLabel(monthStart, format: "MMM"),
                average: average(monthTasks),
                taskCount: monthTasks.count,
                trend: .stable
            ))
        }
        return applyTrends(points)
    }

    /// Best (max-average) point in a series, if any.
    public static func best(_ series: [PerformanceDataPoint]) -> PerformanceDataPoint? {
        series.max { $0.average < $1.average }
    }

    /// Overall trend comparing last vs first weekly average.
    public static func overallTrend(_ weekly: [PerformanceDataPoint]) -> String {
        guard weekly.count > 1, let first = weekly.first, let last = weekly.last else { return "N/A" }
        if last.average > first.average { return "Improving" }
        if last.average < first.average { return "Declining" }
        return "Neutral"
    }

    // MARK: - Helpers

    private static func mondayOfWeek(containing date: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: date) // Sunday = 1
        let daysToMonday = weekday == 1 ? 6 : weekday - 2
        return cal.date(byAdding: .day, value: -daysToMonday, to: date) ?? date
    }

    private static func applyTrends(_ points: [PerformanceDataPoint]) -> [PerformanceDataPoint] {
        var result = points
        for i in 1..<max(result.count, 1) where i < result.count {
            if result[i].average > result[i - 1].average { result[i].trend = .up }
            else if result[i].average < result[i - 1].average { result[i].trend = .down }
            else { result[i].trend = .stable }
        }
        return result
    }

    private static func shortLabel(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = format
        return df.string(from: date)
    }
}
