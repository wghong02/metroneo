import XCTest
@testable import Metroneo

final class PerformanceAnalyticsTests: XCTestCase {
    func testLevelClassification() {
        let c = PerformanceCutoffs.defaults
        XCTAssertEqual(PerformancePreferencesService.level(for: 95, cutoffs: c), .excellent)
        XCTAssertEqual(PerformancePreferencesService.level(for: 82, cutoffs: c), .veryGood)
        XCTAssertEqual(PerformancePreferencesService.level(for: 76, cutoffs: c), .good)
        XCTAssertEqual(PerformancePreferencesService.level(for: 61, cutoffs: c), .fair)
        XCTAssertEqual(PerformancePreferencesService.level(for: 30, cutoffs: c), .poor)
    }

    func testAverageAndFiltering() {
        let now = day("2026-07-21")
        let tasks = [
            Task(title: "recent", deadline: Date(), performanceRating: 80, completedAt: day("2026-07-20"), createDate: day("2026-07-01")),
            Task(title: "old", deadline: Date(), performanceRating: 40, completedAt: day("2026-01-01"), createDate: day("2026-01-01"))
        ]
        let filtered = PerformanceAnalytics.filteredTasks(tasks, period: .week, now: now)
        XCTAssertEqual(filtered.map(\.title), ["recent"])
        XCTAssertEqual(PerformanceAnalytics.average(filtered), 80)
    }

    func testAverageOfEmptyIsZero() {
        XCTAssertEqual(PerformanceAnalytics.average([]), 0)
    }

    func testDateRangeOffsets() {
        let now = day("2026-07-22")
        let cal = Calendar.current
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .week, now: now).end, now)
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .week, now: now).start,
                       cal.date(byAdding: .day, value: -7, to: now))
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .month, now: now).start,
                       cal.date(byAdding: .month, value: -1, to: now))
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .year, now: now).start,
                       cal.date(byAdding: .year, value: -1, to: now))
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .allTime, now: now).start,
                       Date(timeIntervalSince1970: 0))
        XCTAssertEqual(PerformanceAnalytics.dateRange(for: .custom, customStart: day("2026-01-01"), now: now).start,
                       day("2026-01-01"))
    }

    func testFilteredCountMatchesTrendBuckets() {
        let now = day("2026-07-22")
        // Completions on each of the last 10 days, incl. the window's old edge.
        let tasks = (0..<10).map { i in
            Task(title: "t\(i)", deadline: Date(), performanceRating: 70,
                 completedAt: Calendar.current.date(byAdding: .day, value: -i, to: now)!,
                 createDate: day("2026-07-01"))
        }
        for period in [PerformancePeriod.week, .month, .threeMonths] {
            let filtered = PerformanceAnalytics.filteredTasks(tasks, period: period, now: now)
            let bucketTotal = PerformanceAnalytics.trendSeries(tasks, period: period, now: now)
                .reduce(0) { $0 + $1.taskCount }
            XCTAssertEqual(filtered.count, bucketTotal,
                           "\(period) stat count and chart buckets must cover the same tasks")
        }
    }

    func testGranularityFollowsPeriod() {
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .week), .daily)
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .month), .weekly)
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .threeMonths), .biweekly)
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .year), .monthly)
    }

    func testGranularityEscalatesForLongSpans() {
        let now = day("2026-07-22")
        func allTime(earliest key: String) -> PerformanceGranularity {
            let t = [Task(title: "t", deadline: Date(), completedAt: day(key), createDate: day(key))]
            return PerformanceAnalytics.granularity(for: .allTime, tasks: t, now: now)
        }
        XCTAssertEqual(allTime(earliest: "2025-07-01"), .monthly)   // ~12 mo
        XCTAssertEqual(allTime(earliest: "2024-01-01"), .quarterly) // ~30 mo
        XCTAssertEqual(allTime(earliest: "2022-01-01"), .halfYear)  // ~54 mo
        XCTAssertEqual(allTime(earliest: "2005-01-01"), .yearly)    // ~21 yr
    }

    func testTrendSeriesBucketsByGranularity() {
        let now = day("2026-07-22")
        // Week → 7 daily buckets ending today.
        XCTAssertEqual(PerformanceAnalytics.trendSeries([], period: .week, now: now).count, 7)
        // Year → 12 monthly buckets.
        XCTAssertEqual(PerformanceAnalytics.trendSeries([], period: .year, now: now).count, 12)
    }

    func testTrendSeriesBucketsATaskByCompletionDate() {
        let now = day("2026-07-22")
        let tasks = [Task(title: "t", deadline: Date(), performanceRating: 90,
                          completedAt: day("2026-07-22"), createDate: day("2026-07-01"))]
        let series = PerformanceAnalytics.trendSeries(tasks, period: .week, now: now)
        // The task completed today lands in the most recent (last) bucket.
        XCTAssertEqual(series.last?.taskCount, 1)
        XCTAssertEqual(series.last?.average, 90)
        XCTAssertEqual(series.dropLast().reduce(0) { $0 + $1.taskCount }, 0)
    }

    func testWeeklyBucketLabelsUseEndDay() {
        let now = day("2026-07-23")
        // Month → weekly buckets; the most recent bucket is labeled by its end
        // (today), not its start.
        let series = PerformanceAnalytics.trendSeries([], period: .month, now: now)
        XCTAssertEqual(series.last?.period, "Jul 23")
    }

    func testOverallTrendNeutralBand() {
        func pt(_ avg: Double) -> PerformanceDataPoint {
            PerformanceDataPoint(period: "\(avg)", average: avg, taskCount: 1, trend: .stable)
        }
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(80), pt(82)]), "Neutral")    // +2.5%
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(80), pt(84)]), "Neutral")    // +5% (boundary)
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(80), pt(88)]), "Improving")  // +10%
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(80), pt(72)]), "Declining")  // -10%
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(0), pt(50)]), "Improving")   // from zero
    }

    func testEmptyBucketsIgnoredInTrendAndBest() {
        func pt(_ avg: Double, _ count: Int) -> PerformanceDataPoint {
            PerformanceDataPoint(period: "\(avg)-\(count)", average: avg, taskCount: count, trend: .stable)
        }
        // A leading empty bucket (avg 0, no tasks) must not drag the comparison:
        // a flat 80 → 80 series reads Neutral, not Improving-from-zero.
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(0, 0), pt(80, 2), pt(80, 3)]), "Neutral")
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(0, 0), pt(60, 2), pt(90, 3)]), "Improving")
        // best() skips empty buckets even though their average is 0.
        XCTAssertEqual(PerformanceAnalytics.best([pt(0, 0), pt(60, 2), pt(90, 3)])?.average, 90)
        // All-empty series has no best and no trend.
        XCTAssertNil(PerformanceAnalytics.best([pt(0, 0), pt(0, 0)]))
        XCTAssertEqual(PerformanceAnalytics.overallTrend([pt(0, 0), pt(0, 0)]), "N/A")
    }

    func testTrendSeriesLevelCountsDistribution() {
        let now = day("2026-07-22")
        // One task per category under the default cutoffs, all completed today.
        let ratings = [95, 82, 76, 61, 30]   // excellent, veryGood, good, fair, poor
        let tasks = ratings.map {
            Task(title: "t\($0)", deadline: Date(), performanceRating: $0,
                 completedAt: now, createDate: day("2026-07-01"))
        }

        let last = PerformanceAnalytics.trendSeries(tasks, period: .week, now: now).last!
        XCTAssertEqual(last.taskCount, 5)
        let counts = Dictionary(uniqueKeysWithValues: last.levelCounts.map { ($0.level, $0.count) })
        XCTAssertEqual(counts[.excellent], 1)
        XCTAssertEqual(counts[.veryGood], 1)
        XCTAssertEqual(counts[.good], 1)
        XCTAssertEqual(counts[.fair], 1)
        XCTAssertEqual(counts[.poor], 1)

        // The cutoffs argument is honored: lowering "Very Good" to 70 reclassifies
        // both 82 and 76 as Very Good.
        let custom = PerformanceCutoffs(fair: 50, good: 60, veryGood: 70, excellent: 90)
        let lastCustom = PerformanceAnalytics.trendSeries(tasks, period: .week, cutoffs: custom, now: now).last!
        let customCounts = Dictionary(uniqueKeysWithValues: lastCustom.levelCounts.map { ($0.level, $0.count) })
        XCTAssertEqual(customCounts[.veryGood], 2)
        XCTAssertEqual(customCounts[.good], 1)   // 61
        XCTAssertEqual(customCounts[.poor], 1)   // 30
    }

    func testGranularityForCustomPeriod() {
        let now = day("2026-07-22")
        // A custom start's span drives the granularity like the fixed periods do.
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .custom, customStart: day("2026-07-16"), now: now), .daily)    // 6 days
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .custom, customStart: day("2026-06-01"), now: now), .weekly)   // ~51 days
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .custom, customStart: day("2026-04-01"), now: now), .biweekly) // ~112 days
        XCTAssertEqual(PerformanceAnalytics.granularity(for: .custom, customStart: day("2026-01-01"), now: now), .monthly)  // ~6 months
    }
}
