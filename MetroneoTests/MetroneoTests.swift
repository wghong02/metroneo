import XCTest
@testable import Metroneo

final class DateTimeUtilitiesTests: XCTestCase {
    func testFormatTime() {
        XCTAssertEqual(DateTimeUtilities.formatTime("00:00"), "12:00 AM")
        XCTAssertEqual(DateTimeUtilities.formatTime("09:30"), "9:30 AM")
        XCTAssertEqual(DateTimeUtilities.formatTime("12:00"), "12:00 PM")
        XCTAssertEqual(DateTimeUtilities.formatTime("23:30"), "11:30 PM")
    }

    func testIncompleteTasksForDate() {
        let tasks = [
            Task(title: "Due today", deadline: "2026-07-21T23:59:59", completedAt: "na", createDate: "2026-07-01"),
            Task(title: "Done", deadline: "2026-07-21T10:00:00", completedAt: "2026-07-20", createDate: "2026-07-01"),
            Task(title: "Other day", deadline: "2026-07-22T09:00:00", completedAt: "na", createDate: "2026-07-01")
        ]
        let result = DateTimeUtilities.incompleteTasks(tasks, forDate: "2026-07-21")
        XCTAssertEqual(result.map(\.title), ["Due today"])
    }

    func testComposeDeadline() {
        XCTAssertEqual(Task.composeDeadline(date: "2026-07-21", time: nil), "2026-07-21T23:59:59")
        XCTAssertEqual(Task.composeDeadline(date: "2026-07-21", time: "09:30"), "2026-07-21T09:30:00")
    }
}

final class InMemoryDatabaseTests: XCTestCase {
    func testSaveAssignsIDsAndReloads() throws {
        let db = InMemoryDatabase()
        try db.saveTasks([
            Task(title: "A", deadline: "2026-07-21T23:59:59", createDate: "2026-07-02",
                 subTasks: [SubTask(title: "sub")]),
            Task(title: "B", deadline: "2026-07-22T23:59:59", createDate: "2026-07-01")
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
        let e = Event(id: "e1", date: "2026-07-21", title: "Meeting", startTime: "09:00")
        try db.saveEvent(e)
        XCTAssertEqual(try db.events(forDate: "2026-07-21").count, 1)
        try db.deleteEvent(id: "e1")
        XCTAssertEqual(try db.events(forDate: "2026-07-21").count, 0)
    }
}

final class TaskServiceTests: XCTestCase {
    private func makeService() -> TaskService { TaskService(db: InMemoryDatabase()) }

    func testAddAndComplete() {
        let s = makeService()
        s.addTask(Task(title: "Write", deadline: "2026-07-21T23:59:59", createDate: "2026-07-20"))
        XCTAssertEqual(s.tasks.count, 1)
        let id = s.tasks[0].id!
        s.updateTaskPerformance(id: id, performance: 85, notes: "good")
        s.completeTask(id: id)
        XCTAssertTrue(s.tasks[0].isCompleted)
        XCTAssertEqual(s.tasks[0].performanceRating, 85)
    }

    func testBlankTitleDefaults() {
        let s = makeService()
        s.addTask(Task(title: "   ", deadline: "2026-07-21T23:59:59", createDate: "2026-07-20"))
        XCTAssertEqual(s.tasks[0].title, "New Task")
    }

    func testToggleSubTask() {
        let s = makeService()
        s.addTask(Task(title: "Parent", deadline: "2026-07-21T23:59:59", createDate: "2026-07-20",
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
        let now = DateTimeUtilities.date(fromKey: "2026-07-21")!
        let tasks = [
            Task(title: "recent", deadline: "x", performanceRating: 80, completedAt: "2026-07-20", createDate: "2026-07-01"),
            Task(title: "old", deadline: "x", performanceRating: 40, completedAt: "2026-01-01", createDate: "2026-01-01")
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
