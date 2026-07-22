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
        XCTAssertFalse(DateTimeUtilities.hasExplicitTime(eod))
        XCTAssertEqual(cal.component(.hour, from: eod), 23)
        XCTAssertEqual(cal.component(.minute, from: eod), 59)

        let nineThirty = cal.date(bySettingHour: 9, minute: 30, second: 0, of: d)!
        let combined = DateTimeUtilities.combine(day: d, time: nineThirty)
        XCTAssertTrue(DateTimeUtilities.hasExplicitTime(combined))
        XCTAssertEqual(cal.component(.hour, from: combined), 9)
        XCTAssertEqual(cal.component(.minute, from: combined), 30)
    }
}

final class InMemoryDatabaseTests: XCTestCase {
    func testSaveAssignsIDsAndReloads() throws {
        let db = InMemoryDatabase()
        try db.saveTasks([
            Task(title: "A", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-02"),
                 subTasks: [SubTask(title: "sub")]),
            Task(title: "B", deadline: DateTimeUtilities.endOfDay(day("2026-07-22")), createDate: day("2026-07-01"))
        ])
        let loaded = try db.loadTasks()
        XCTAssertEqual(loaded.count, 2)
        // Ordered by createDate DESC.
        XCTAssertEqual(loaded.first?.title, "A")
        XCTAssertNotNil(loaded.first?.id)
        XCTAssertEqual(loaded.first?.subTasks.first?.order, 0)
        XCTAssertNotNil(loaded.first?.subTasks.first?.id)
    }

    func testEventUpsertAndDelete() throws {
        let db = InMemoryDatabase()
        let e = Event(id: "e1", date: day("2026-07-21"), title: "Meeting",
                      startTime: DateTimeUtilities.combine(day: day("2026-07-21"),
                                                           time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!))
        try db.saveEvent(e)
        XCTAssertEqual(try db.events(forDate: day("2026-07-21")).count, 1)
        try db.deleteEvent(id: "e1")
        XCTAssertEqual(try db.events(forDate: day("2026-07-21")).count, 0)
    }
}

final class TaskServiceTests: XCTestCase {
    private func makeService() -> TaskService { TaskService(db: InMemoryDatabase()) }

    func testAddAndComplete() {
        let s = makeService()
        s.addTask(Task(title: "Write", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20")))
        XCTAssertEqual(s.tasks.count, 1)
        let id = s.tasks[0].id!
        s.updateTaskPerformance(id: id, performance: 85, notes: "good")
        s.completeTask(id: id)
        XCTAssertTrue(s.tasks[0].isCompleted)
        XCTAssertEqual(s.tasks[0].performanceRating, 85)
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

    func testWeeklySeriesHasFivePoints() {
        let series = PerformanceAnalytics.weeklySeries([])
        XCTAssertEqual(series.count, 5)
    }
}
