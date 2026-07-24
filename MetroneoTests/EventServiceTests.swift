import XCTest
@testable import Metroneo

final class EventServiceTests: XCTestCase {
    private func makeService() -> (EventService, SwiftDataDatabase) {
        let db = try! SwiftDataDatabase(inMemory: true)
        return (EventService(db: db), db)
    }

    func testAddGroupsByStartOfDayAndAnchorsTimes() {
        let (svc, _) = makeService()
        let cal = Calendar.current
        // Add "against" a mid-afternoon instant; the event carries a stale date and
        // a 9:30 start time anchored to a *different* day.
        let targetInstant = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day("2026-07-21"))!
        let staleStart = cal.date(bySettingHour: 9, minute: 30, second: 0, of: day("2026-01-05"))!
        svc.addEvent(date: targetInstant, event: Event(date: day("2026-01-05"), title: "Meeting", startTime: staleStart))

        let list = svc.events(on: day("2026-07-21"))
        XCTAssertEqual(list.map(\.title), ["Meeting"])
        // Event is normalized to the target day's start.
        XCTAssertEqual(list.first?.date, day("2026-07-21"))
        // Start time keeps 9:30 but is re-anchored onto Jul 21.
        let start = list.first!.startTime!
        XCTAssertTrue(cal.isDate(start, inSameDayAs: day("2026-07-21")))
        XCTAssertEqual(cal.component(.hour, from: start), 9)
        XCTAssertEqual(cal.component(.minute, from: start), 30)
    }

    func testUpdateReplacesAndDeletePrunesDay() {
        let (svc, db) = makeService()
        let d = day("2026-07-21")
        svc.addEvent(date: d, event: Event(id: "e1", date: d, title: "First", allDay: true))
        svc.updateEvent(date: d, event: Event(id: "e1", date: d, title: "Renamed", allDay: true))
        XCTAssertEqual(svc.events(on: d).map(\.title), ["Renamed"])   // in-place update

        svc.deleteEvent(date: d, id: "e1")
        XCTAssertTrue(svc.events(on: d).isEmpty)
        // A fresh service confirms the delete persisted, not just the cache.
        let reloaded = EventService(db: db)
        reloaded.loadEvents()
        XCTAssertTrue(reloaded.events(on: d).isEmpty)
    }

    func testLoadGroupsPersistedEventsByDay() {
        let (svc, db) = makeService()
        svc.addEvent(date: day("2026-07-21"), event: Event(date: day("2026-07-21"), title: "A"))
        svc.addEvent(date: day("2026-07-21"), event: Event(date: day("2026-07-21"), title: "B"))
        svc.addEvent(date: day("2026-07-22"), event: Event(date: day("2026-07-22"), title: "C"))

        let reloaded = EventService(db: db)
        reloaded.loadEvents()
        XCTAssertEqual(reloaded.events(on: day("2026-07-21")).count, 2)
        XCTAssertEqual(reloaded.events(on: day("2026-07-22")).map(\.title), ["C"])
        XCTAssertTrue(reloaded.events(on: day("2026-07-23")).isEmpty)
    }

    func testMakeIDFormat() {
        // "event-{millis}-{rand}" — millis is the timestamp in milliseconds.
        let id = Event.makeID(date: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(id.hasPrefix("event-"))
        let parts = id.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "event")
        XCTAssertEqual(Int(parts[1]), 1000)   // 1s → 1000 ms
        XCTAssertNotNil(Int(parts[2]))        // random suffix
    }
}
