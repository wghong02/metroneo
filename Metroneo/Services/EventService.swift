import Foundation
import Combine

/// Observable event cache grouped by day, backed by a ``TaskDatabase``
/// (FUNCTIONALITY.md §4.2). Keys are local start-of-day dates.
public final class EventService: ObservableObject {
    @Published public private(set) var eventsByDate: EventMap = [:]

    private let db: TaskDatabase

    public init(db: TaskDatabase) {
        self.db = db
    }

    @discardableResult
    public func loadEvents() -> EventMap {
        let all = (try? db.loadEvents()) ?? []
        var grouped: EventMap = [:]
        for event in all { grouped[DateTimeUtilities.startOfDay(event.date), default: []].append(event) }
        eventsByDate = grouped
        return grouped
    }

    public func events(on date: Date) -> [Event] { eventsByDate[DateTimeUtilities.startOfDay(date)] ?? [] }

    public func addEvent(date: Date, event: Event) {
        let day = DateTimeUtilities.startOfDay(date)
        let e = anchor(event, to: day)
        do {
            try db.saveEvent(e)
            eventsByDate[day, default: []].append(e)
        } catch {
            print("[EventService] Error adding event:", error)
        }
    }

    public func updateEvent(date: Date, event: Event) {
        let day = DateTimeUtilities.startOfDay(date)
        let e = anchor(event, to: day)
        do {
            try db.saveEvent(e)
            eventsByDate[day] = (eventsByDate[day] ?? []).map { $0.id == e.id ? e : $0 }
        } catch {
            print("[EventService] Error updating event:", error)
        }
    }

    public func deleteEvent(date: Date, id: String) {
        let day = DateTimeUtilities.startOfDay(date)
        do {
            try db.deleteEvent(id: id)
            let list = (eventsByDate[day] ?? []).filter { $0.id != id }
            if list.isEmpty { eventsByDate.removeValue(forKey: day) } else { eventsByDate[day] = list }
        } catch {
            print("[EventService] Error deleting event:", error)
        }
    }

    /// Re-dates an event and moves it between day buckets.
    public func moveEvent(oldDate: Date, newDate: Date, id: String) {
        let oldDay = DateTimeUtilities.startOfDay(oldDate)
        guard let existing = (eventsByDate[oldDay] ?? []).first(where: { $0.id == id }) else { return }
        let newDay = DateTimeUtilities.startOfDay(newDate)
        let event = anchor(existing, to: newDay)
        do {
            try db.saveEvent(event)
            let oldList = (eventsByDate[oldDay] ?? []).filter { $0.id != id }
            if oldList.isEmpty { eventsByDate.removeValue(forKey: oldDay) } else { eventsByDate[oldDay] = oldList }
            eventsByDate[newDay, default: []].append(event)
        } catch {
            print("[EventService] Error moving event:", error)
        }
    }

    /// Pins an event to `day`: sets its date and re-anchors any start/end time to
    /// that day (times are stored as instants but only their time-of-day matters).
    private func anchor(_ event: Event, to day: Date) -> Event {
        var e = event
        e.date = day
        if let start = e.startTime { e.startTime = DateTimeUtilities.combine(day: day, time: start) }
        if let end = e.endTime { e.endTime = DateTimeUtilities.combine(day: day, time: end) }
        return e
    }
}
