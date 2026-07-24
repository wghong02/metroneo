import XCTest
@testable import Metroneo

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

    func testSaveTasksReplacesWholeSet() throws {
        let db = try makeDB()
        try db.saveTasks([
            Task(id: "a", title: "A", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-02")),
            Task(id: "b", title: "B", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-01"))
        ])
        // Saving a new set drops the previous rows entirely (delete-all + insert).
        try db.saveTasks([
            Task(id: "c", title: "C", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-03"))
        ])
        XCTAssertEqual(try db.loadTasks().map(\.id), ["c"])
    }

    func testBlankTitlesDefaultOnSave() throws {
        let db = try makeDB()
        try db.saveTasks([
            Task(id: "t", title: "   ", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-01"),
                 subTasks: [SubTask(id: "s", title: "  ")])
        ])
        let loaded = try db.loadTasks().first
        XCTAssertEqual(loaded?.title, "New Task")
        XCTAssertEqual(loaded?.subTasks.first?.title, "New Subtask")
    }

    func testEventTitleRequired() throws {
        let db = try makeDB()
        XCTAssertThrowsError(try db.saveEvent(Event(date: day("2026-07-21"), title: "")))
    }

    func testResetClearsAllDataAndStatsCount() throws {
        let db = try makeDB()
        try db.saveTasks([
            Task(title: "A", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-01"),
                 subTasks: [SubTask(title: "s1"), SubTask(title: "s2")])
        ])
        try db.saveEvent(Event(date: day("2026-07-21"), title: "E"))

        let before = db.stats()
        XCTAssertEqual(before.taskCount, 1)
        XCTAssertEqual(before.subTaskCount, 2)
        XCTAssertEqual(before.eventCount, 1)

        try db.reset()
        XCTAssertTrue(try db.loadTasks().isEmpty)
        XCTAssertTrue(try db.loadEvents().isEmpty)
        let after = db.stats()
        XCTAssertEqual([after.taskCount, after.subTaskCount, after.eventCount], [0, 0, 0])
    }

    func testResaveOverExistingSubtasksSucceeds() throws {
        let db = try makeDB()
        let withSub = Task(id: "p", title: "P", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                           createDate: day("2026-07-01"), subTasks: [SubTask(id: "s", title: "child")])
        try db.saveTasks([withSub])
        // Re-saving over a task that already has subtasks must not trip the
        // cascade/inverse constraint (regression: batch-deleting the children).
        try db.saveTasks([withSub])
        let loaded = try db.loadTasks()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.subTasks.map(\.id), ["s"])
        XCTAssertEqual(db.stats().subTaskCount, 1)   // not duplicated, not leaked
    }

    func testLoadEventsSortedByDateThenStartThenTitle() throws {
        let db = try makeDB()
        let cal = Calendar.current
        let d1 = day("2026-07-21")
        let nine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: d1)!
        let ten = cal.date(bySettingHour: 10, minute: 0, second: 0, of: d1)!
        // Insert out of order. Expect: date → startTime → title.
        try db.saveEvent(Event(id: "later-day", date: day("2026-07-22"), title: "Zebra"))
        try db.saveEvent(Event(id: "ten", date: d1, title: "Ten", startTime: ten))
        try db.saveEvent(Event(id: "nine", date: d1, title: "Nine", startTime: nine))
        // Same date + same start time → title breaks the tie.
        try db.saveEvent(Event(id: "beta", date: d1, title: "Beta", startTime: nine))
        try db.saveEvent(Event(id: "alpha", date: d1, title: "Alpha", startTime: nine))

        XCTAssertEqual(try db.loadEvents().map(\.title),
                       ["Alpha", "Beta", "Nine", "Ten", "Zebra"])
    }

    func testSubtasksLoadInOrderIndexOrder() throws {
        let db = try makeDB()
        // Subtasks get their orderIndex from array position; loadTasks re-sorts by it.
        try db.saveTasks([
            Task(id: "p", title: "P", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-01"),
                 subTasks: [SubTask(id: "s0", title: "first"),
                            SubTask(id: "s1", title: "second"),
                            SubTask(id: "s2", title: "third")])
        ])
        let subs = try db.loadTasks().first!.subTasks
        XCTAssertEqual(subs.map(\.id), ["s0", "s1", "s2"])
        XCTAssertEqual(subs.map(\.order), [0, 1, 2])
    }

    func testEmptyTypesRoundTripToNil() throws {
        let db = try makeDB()
        try db.saveTasks([
            Task(id: "n", title: "nil types", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                 createDate: day("2026-07-01"), types: nil),
            Task(id: "e", title: "empty types", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")),
                 createDate: day("2026-07-02"), types: [])
        ])
        let byID = Dictionary(uniqueKeysWithValues: try db.loadTasks().map { ($0.id!, $0) })
        XCTAssertNil(byID["n"]?.types)
        XCTAssertNil(byID["e"]?.types)   // empty array normalizes back to nil on load
    }
}
