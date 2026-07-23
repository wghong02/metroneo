import XCTest
@testable import Metroneo

/// Local start-of-day `Date` for a `"YYYY-MM-DD"` key.
private func day(_ key: String) -> Date {
    let p = key.split(separator: "-").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
}

final class DateTimeUtilitiesTests: XCTestCase {
    func testIncompleteTasksForDate() {
        let tasks = [
            Task(title: "Due today", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                 completedAt: nil, createDate: day("2026-07-01")),
            Task(title: "Done", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                 completedAt: day("2026-07-20"), createDate: day("2026-07-01")),
            Task(title: "Other day", deadline: DateTimeUtilities.endOfDay(day("2026-07-22")),
                 completedAt: nil, createDate: day("2026-07-01"))
        ]
        let result = DateTimeUtilities.incompleteTasks(tasks, forDate: day("2026-07-21"))
        XCTAssertEqual(result.map(\.title), ["Due today"])
    }

    func testDeadlineComposition() {
        let cal = Calendar.current
        let d = day("2026-07-21")

        let eod = DateTimeUtilities.endOfDay(d)
        XCTAssertEqual(cal.component(.hour, from: eod), 23)
        XCTAssertEqual(cal.component(.minute, from: eod), 59)

        let nineThirty = cal.date(bySettingHour: 9, minute: 30, second: 0, of: d)!
        let combined = DateTimeUtilities.combine(day: d, time: nineThirty)
        XCTAssertEqual(cal.component(.hour, from: combined), 9)
        XCTAssertEqual(cal.component(.minute, from: combined), 30)
    }

    func testFormatDeadlineShowsTimeOnlyWhenFlagged() {
        let cal = Calendar.current
        let deadline = cal.date(bySettingHour: 9, minute: 30, second: 0, of: day("2026-07-21"))!
        XCTAssertFalse(DateTimeUtilities.formatDeadline(deadline, hasTime: false).contains("at"))
        XCTAssertTrue(DateTimeUtilities.formatDeadline(deadline, hasTime: true).contains("at"))
    }
}

final class SwiftDataDatabaseTests: XCTestCase {
    private func makeDB() throws -> SwiftDataDatabase { try SwiftDataDatabase(inMemory: true) }

    func testTaskRoundTripPreservesIDsAndSubtasks() throws {
        let db = try makeDB()
        try db.saveTasks([
            Task(id: "keep-me", title: "A", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                 hasDeadlineTime: true,
                 completedAt: day("2026-07-20"), createDate: day("2026-07-02"),
                 types: ["work"], subTasks: [SubTask(id: "s1", title: "child")]),
            Task(title: "B", deadline: DateTimeUtilities.endOfDay(day("2026-07-22")), createDate: day("2026-07-01"))
        ])
        let loaded = try db.loadTasks()
        XCTAssertEqual(loaded.map(\.title), ["A", "B"])          // createDate DESC
        XCTAssertEqual(loaded.first?.id, "keep-me")               // id preserved
        XCTAssertEqual(loaded.first?.hasDeadlineTime, true)        // flag round-trips
        XCTAssertEqual(loaded.first?.types, ["work"])
        XCTAssertEqual(loaded.first?.completedAt, day("2026-07-20"))
        XCTAssertEqual(loaded.first?.subTasks.first?.id, "s1")
        XCTAssertEqual(loaded.first?.subTasks.first?.order, 0)
    }

    func testEventUpsertAndDelete() throws {
        let db = try makeDB()
        try db.saveEvent(Event(id: "e1", date: day("2026-07-21"), title: "Meeting"))
        try db.saveEvent(Event(id: "e1", date: day("2026-07-21"), title: "Renamed"))
        XCTAssertEqual(try db.loadEvents().map(\.title), ["Renamed"])  // upsert, not dup
        try db.deleteEvent(id: "e1")
        XCTAssertTrue(try db.loadEvents().isEmpty)
    }
}

final class TaskServiceTests: XCTestCase {
    private func makeService() -> TaskService { TaskService(db: try! SwiftDataDatabase(inMemory: true)) }

    private func sampleTask(_ title: String = "Write") -> Task {
        Task(title: title, deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20"))
    }

    func testMutationsAreInMemoryUntilSave() {
        let s = makeService()
        s.addTask(sampleTask())
        XCTAssertTrue(s.hasUnsavedChanges)
        let id = s.tasks[0].id!

        // Two edits against the same captured id — must both land on one task.
        s.updateTaskPerformance(id: id, performance: 85, notes: "good")
        s.completeTask(id: id)
        XCTAssertTrue(s.tasks[0].isCompleted)
        XCTAssertEqual(s.tasks[0].performanceRating, 85)

        s.save()
        XCTAssertFalse(s.hasUnsavedChanges)
    }

    func testIDsStableAcrossSaves() {
        let s = makeService()
        s.addTask(sampleTask())
        let id = s.tasks[0].id!

        s.save()
        XCTAssertEqual(s.tasks[0].id, id, "id must survive a save")

        s.completeTask(id: id)
        s.save()
        XCTAssertEqual(s.tasks[0].id, id, "id must survive further saves")
        XCTAssertTrue(s.tasks[0].isCompleted)
    }

    func testDiscardRestoresPersistedState() {
        let s = makeService()
        s.addTask(sampleTask())
        s.save()
        s.deleteTask(id: s.tasks[0].id!)
        XCTAssertTrue(s.tasks.isEmpty)

        s.discardChanges()
        XCTAssertEqual(s.tasks.count, 1)
        XCTAssertFalse(s.hasUnsavedChanges)
    }

    func testBlankTitleDefaults() {
        let s = makeService()
        s.addTask(Task(title: "   ", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20")))
        XCTAssertEqual(s.tasks[0].title, "New Task")
    }

    func testToggleSubTask() {
        let s = makeService()
        s.addTask(Task(title: "Parent", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20"),
                       subTasks: [SubTask(title: "child")]))
        let tid = s.tasks[0].id!
        let sid = s.tasks[0].subTasks[0].id!
        s.toggleSubTask(taskId: tid, subTaskId: sid)
        XCTAssertTrue(s.tasks[0].subTasks[0].isCompleted)
    }
}

final class PerformanceTests: XCTestCase {
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
}
