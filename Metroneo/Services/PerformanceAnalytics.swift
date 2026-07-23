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

/// Bucket size for the adaptive trend chart. The month-based tiers form an
/// escalation ladder (monthly → quarterly → half-year → yearly) so a long span
/// stays within 12 buckets.
public enum PerformanceGranularity: Equatable {
    case daily, weekly, biweekly, monthly, quarterly, halfYear, yearly

    public var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .halfYear: return "Half-Year"
        case .yearly: return "Yearly"
        }
    }

    /// Month step for month-based tiers; `nil` for day-based tiers.
    var monthStep: Int? {
        switch self {
        case .monthly: return 1
        case .quarterly: return 3
        case .halfYear: return 6
        case .yearly: return 12
        case .daily, .weekly, .biweekly: return nil
        }
    }

    /// Day step for day-based tiers; `nil` for month-based tiers.
    var dayStep: Int? {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly, .quarterly, .halfYear, .yearly: return nil
        }
    }
}

/// Trend of a data point relative to the previous one.
public enum PerformanceTrend: Equatable { case up, down, stable }

/// Number of tasks at a given performance level within a bucket.
public struct LevelCount: Equatable {
    public var level: PerformanceLevel
    public var count: Int
    public init(level: PerformanceLevel, count: Int) {
        self.level = level
        self.count = count
    }
}

/// One point in the trend series.
public struct PerformanceDataPoint: Equatable {
    public var period: String
    public var average: Double
    public var taskCount: Int
    /// Per-category breakdown of the bucket's tasks (for the distribution bars).
    public var levelCounts: [LevelCount]
    public var trend: PerformanceTrend

    public init(period: String, average: Double, taskCount: Int,
                levelCounts: [LevelCount] = [], trend: PerformanceTrend) {
        self.period = period
        self.average = average
        self.taskCount = taskCount
        self.levelCounts = levelCounts
        self.trend = trend
    }
}

/// Pure analytics over completed tasks (FUNCTIONALITY.md §8).
public enum PerformanceAnalytics {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// Start/end range for a period. `now` and `customStart` are injectable for tests.
    public static func dateRange(
        for period: PerformancePeriod,
        customStart: Date? = nil,
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
        case .custom:      start = customStart ?? (cal.date(byAdding: .day, value: -7, to: now) ?? now)
        }
        return (start, end)
    }

    /// Completed tasks whose `completedAt` falls within the period.
    public static func filteredTasks(
        _ tasks: [Task],
        period: PerformancePeriod,
        customStart: Date? = nil,
        now: Date = Date()
    ) -> [Task] {
        let range = dateRange(for: period, customStart: customStart, now: now)
        return tasks.filter { task in
            guard let d = task.completedAt else { return false }
            return d >= range.start && d <= range.end
        }
    }

    /// Average performance across the given tasks (0 if empty).
    public static func average(_ tasks: [Task]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let sum = tasks.reduce(0) { $0 + $1.performanceRating }
        return Double(sum) / Double(tasks.count)
    }

    /// Bucket granularity for the trend chart, chosen from the window span so it
    /// stays within 12 buckets (Week→daily, Month→weekly, 3 Months→biweekly, up to
    /// 12mo→monthly, 36mo→quarterly, 72mo→half-year, else yearly).
    public static func granularity(
        for period: PerformancePeriod,
        tasks: [Task] = [],
        customStart: Date? = nil,
        now: Date = Date()
    ) -> PerformanceGranularity {
        let cal = calendar
        let start = windowStart(for: period, customStart: customStart, tasks: tasks, now: now)
        let days = cal.dateComponents([.day], from: start, to: now).day ?? 0
        let months = cal.dateComponents([.month], from: start, to: now).month ?? 0
        if days <= 12 { return .daily }
        if days <= 62 { return .weekly }
        if days <= 168 { return .biweekly }   // ~3 months → biweekly
        if months <= 12 { return .monthly }
        if months <= 36 { return .quarterly }
        if months <= 72 { return .halfYear }
        return .yearly
    }

    /// Adaptive trend series (oldest → newest): the bucket size follows the
    /// selected period (daily / weekly / monthly), and the most recent bucket
    /// ends today. Each point averages the `performanceRating` of the tasks
    /// completed in its bucket.
    public static func trendSeries(
        _ tasks: [Task],
        period: PerformancePeriod,
        cutoffs: PerformanceCutoffs = .defaults,
        customStart: Date? = nil,
        now: Date = Date()
    ) -> [PerformanceDataPoint] {
        let cal = calendar
        let gran = granularity(for: period, tasks: tasks, customStart: customStart, now: now)
        let start = windowStart(for: period, customStart: customStart, tasks: tasks, now: now)
        let count = bucketCount(granularity: gran, from: start, to: now, cal: cal)

        var points: [PerformanceDataPoint] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            let b = bucket(index: i, granularity: gran, now: now, cal: cal)
            let bucketTasks = tasks.filter { task in
                guard let d = task.completedAt else { return false }
                return d >= b.begin && d < b.end
            }
            let levelCounts = PerformanceLevel.allCases.map { level in
                LevelCount(level: level, count: bucketTasks.filter {
                    PerformancePreferencesService.level(for: $0.performanceRating, cutoffs: cutoffs) == level
                }.count)
            }
            points.append(PerformanceDataPoint(
                period: b.label,
                average: average(bucketTasks),
                taskCount: bucketTasks.count,
                levelCounts: levelCounts,
                trend: .stable
            ))
        }
        return applyTrends(points)
    }

    /// Best (max-average) point in a series, if any.
    public static func best(_ series: [PerformanceDataPoint]) -> PerformanceDataPoint? {
        series.max { $0.average < $1.average }
    }

    /// Overall trend comparing the last vs first bucket average of a series.
    /// A percentage change (relative to the first bucket) within ±5% is Neutral.
    public static func overallTrend(_ series: [PerformanceDataPoint]) -> String {
        guard series.count > 1, let first = series.first, let last = series.last else { return "N/A" }
        guard first.average != 0 else { return last.average > 0 ? "Improving" : "Neutral" }
        let percentChange = (last.average - first.average) / first.average * 100
        if percentChange > 5 { return "Improving" }
        if percentChange < -5 { return "Declining" }
        return "Neutral"
    }

    // MARK: - Helpers

    /// Start of the analysis window. For All Time this is the earliest completion
    /// so buckets don't stretch back to the epoch.
    private static func windowStart(
        for period: PerformancePeriod, customStart: Date?, tasks: [Task], now: Date
    ) -> Date {
        if period == .allTime {
            return tasks.compactMap(\.completedAt).min() ?? now
        }
        return dateRange(for: period, customStart: customStart, now: now).start
    }

    /// Number of buckets covering `[start, now]` at the given granularity
    /// (clamped so the chart never shows more than 12 buckets).
    private static func bucketCount(
        granularity: PerformanceGranularity, from start: Date, to now: Date, cal: Calendar
    ) -> Int {
        let cap = 12
        let n: Int
        if let step = granularity.monthStep {
            let months = cal.dateComponents([.month], from: start, to: now).month ?? 0
            n = Int((Double(months) / Double(step)).rounded(.up))
        } else if granularity == .daily {
            n = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: now)).day ?? 0
        } else { // weekly / biweekly
            let days = cal.dateComponents([.day], from: start, to: now).day ?? 0
            n = Int((Double(days) / Double(granularity.dayStep ?? 7)).rounded(.up))
        }
        return max(1, min(cap, n))
    }

    /// The `i`-th most recent bucket (`i == 0` is the current one). Windows are
    /// half-open `[begin, end)`; month-based buckets are calendar-aligned.
    private static func bucket(
        index i: Int, granularity: PerformanceGranularity, now: Date, cal: Calendar
    ) -> (begin: Date, end: Date, label: String) {
        if let step = granularity.monthStep {
            let base = alignedMonthStart(now, step: step, cal: cal)
            let begin = cal.date(byAdding: .month, value: -i * step, to: base) ?? base
            let end = cal.date(byAdding: .month, value: step, to: begin) ?? begin
            return (begin, end, monthTierLabel(begin, granularity: granularity, cal: cal))
        }
        if granularity == .daily {
            let day = cal.date(byAdding: .day, value: -i, to: now) ?? now
            let begin = cal.startOfDay(for: day)
            let end = cal.date(byAdding: .day, value: 1, to: begin) ?? day
            return (begin, end, shortLabel(begin, format: "MMM d"))
        }
        // weekly / biweekly: rolling windows of `step` calendar days, the most
        // recent ending at the end of today (so the current bucket includes today).
        let step = granularity.dayStep ?? 7
        let endOfToday = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let end = cal.date(byAdding: .day, value: -step * i, to: endOfToday) ?? endOfToday
        let begin = cal.date(byAdding: .day, value: -step, to: end) ?? end
        return (begin, end, shortLabel(begin, format: "MMM d"))
    }

    /// First day of the `step`-month block containing `date` (e.g. calendar
    /// quarter / half / year start).
    private static func alignedMonthStart(_ date: Date, step: Int, cal: Calendar) -> Date {
        let c = cal.dateComponents([.year, .month], from: date)
        let absMonth = (c.year ?? 0) * 12 + ((c.month ?? 1) - 1)
        let aligned = (absMonth / step) * step
        var out = DateComponents()
        out.year = aligned / 12
        out.month = aligned % 12 + 1
        out.day = 1
        return cal.date(from: out) ?? date
    }

    /// Label for a month-based bucket beginning at `begin`.
    private static func monthTierLabel(_ begin: Date, granularity: PerformanceGranularity, cal: Calendar) -> String {
        switch granularity {
        case .quarterly:
            return shortLabel(begin, format: "QQQ ''yy")   // e.g. "Q3 '26"
        case .yearly:
            return shortLabel(begin, format: "yyyy")        // e.g. "2026"
        case .halfYear:
            let half = (cal.component(.month, from: begin) - 1) < 6 ? 1 : 2
            return "H\(half) \(shortLabel(begin, format: "''yy"))" // e.g. "H2 '26"
        default: // monthly — include year so names don't collide across years
            return shortLabel(begin, format: "MMM ''yy")    // e.g. "Jul '26"
        }
    }

    private static func applyTrends(_ points: [PerformanceDataPoint]) -> [PerformanceDataPoint] {
        guard points.count > 1 else { return points }
        var result = points
        for i in 1..<result.count {
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
