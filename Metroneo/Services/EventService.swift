import Foundation
import Combine

/// Observable event cache grouped by day, backed by a ``SwiftDataDatabase``
/// (FUNCTIONALITY.md §4.2). Keys are local start-of-day dates.
public final class EventService: ObservableObject {
    @Published public private(set) var eventsByDate: EventMap = [:]

    private let db: SwiftDataDatabase

    public init(db: SwiftDataDatabase) {
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
            Log.eventError("Failed to add event: \(error)")
        }
    }

    public func updateEvent(date: Date, event: Event) {
        let day = DateTimeUtilities.startOfDay(date)
        let e = anchor(event, to: day)
        do {
            try db.saveEvent(e)
            eventsByDate[day] = (eventsByDate[day] ?? []).map { $0.id == e.id ? e : $0 }
        } catch {
            Log.eventError("Failed to update event: \(error)")
        }
    }

    public func deleteEvent(date: Date, id: String) {
        let day = DateTimeUtilities.startOfDay(date)
        do {
            try db.deleteEvent(id: id)
            let list = (eventsByDate[day] ?? []).filter { $0.id != id }
            if list.isEmpty { eventsByDate.removeValue(forKey: day) } else { eventsByDate[day] = list }
        } catch {
            Log.eventError("Failed to delete event: \(error)")
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
