import XCTest
@testable import Plannus

final class TimeUtilitiesTests: XCTestCase {
    func testFormatTime() {
        XCTAssertEqual(TimeUtilities.formatTime("00:00"), "12:00 AM")
        XCTAssertEqual(TimeUtilities.formatTime("09:30"), "9:30 AM")
        XCTAssertEqual(TimeUtilities.formatTime("12:00"), "12:00 PM")
        XCTAssertEqual(TimeUtilities.formatTime("13:05"), "1:05 PM")
        XCTAssertEqual(TimeUtilities.formatTime("23:30"), "11:30 PM")
    }

    func testFormatTimePassesThroughInvalid() {
        XCTAssertEqual(TimeUtilities.formatTime("nope"), "nope")
    }

    func testGenerateTimeOptions() {
        let options = TimeUtilities.generateTimeOptions()
        XCTAssertEqual(options.count, 48)
        XCTAssertEqual(options.first, "00:00")
        XCTAssertEqual(options.last, "23:30")
        XCTAssertEqual(options[2], "01:00")
    }
}

final class TaskStoreTests: XCTestCase {
    private func makeStore() -> TaskStore { TaskStore(store: InMemoryStore()) }

    func testAddTaskAppendsAndSorts() {
        let store = makeStore()
        store.saveTask(date: "d", title: "Late", time: "14:00", notes: "")
        store.saveTask(date: "d", title: "Early", time: "08:00", notes: "")
        XCTAssertEqual(store.tasks(on: "d").map(\.time), ["08:00", "14:00"])
        XCTAssertEqual(store.tasks(on: "d").first?.title, "Early")
    }

    func testEmptyTitleIsNoOp() {
        let store = makeStore()
        store.saveTask(date: "d", title: "   ", time: "09:00", notes: "")
        XCTAssertTrue(store.tasks(on: "d").isEmpty)
    }

    func testEditPreservesID() {
        let store = makeStore()
        store.saveTask(date: "d", title: "Old", time: "09:00", notes: "")
        let id = store.tasks(on: "d").first?.id
        store.saveTask(date: "d", title: "New", time: "09:00", notes: "n", editIndex: 0)
        XCTAssertEqual(store.tasks(on: "d").first?.id, id)
        XCTAssertEqual(store.tasks(on: "d").first?.title, "New")
    }

    func testDeleteRemovesByIndex() {
        let store = makeStore()
        store.saveTask(date: "d", title: "A", time: "08:00", notes: "")
        store.saveTask(date: "d", title: "B", time: "09:00", notes: "")
        store.deleteTask(date: "d", index: 0)
        XCTAssertEqual(store.tasks(on: "d").map(\.title), ["B"])
    }

    func testPersistenceRoundTripsAcrossInstances() {
        let backing = InMemoryStore()
        let a = TaskStore(store: backing)
        a.saveTask(date: "d", title: "A", time: "08:00", notes: "")
        let b = TaskStore(store: backing)
        XCTAssertEqual(b.tasks(on: "d").map(\.title), ["A"])
    }
}

final class TodoStoreTests: XCTestCase {
    func testAddTrimsAndIgnoresEmpty() {
        let store = TodoStore(store: InMemoryStore())
        store.addTodo("  buy milk  ")
        store.addTodo("   ")
        XCTAssertEqual(store.todos, ["buy milk"])
    }

    func testDeleteByIndex() {
        let store = TodoStore(store: InMemoryStore())
        ["a", "b", "c"].forEach(store.addTodo)
        store.deleteTodo(at: 1)
        XCTAssertEqual(store.todos, ["a", "c"])
    }
}

final class DateKeyTests: XCTestCase {
    func testDateKeyFormat() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 21
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        XCTAssertEqual(TimeUtilities.dateKey(for: date), "2026-07-21")
    }
}
