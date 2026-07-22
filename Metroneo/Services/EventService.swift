import Foundation
import Combine

/// Observable event cache grouped by date, backed by a ``TaskDatabase``
/// (FUNCTIONALITY.md §4.2).
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
        for event in all { grouped[event.date, default: []].append(event) }
        eventsByDate = grouped
        return grouped
    }

    public func events(on date: String) -> [Event] { eventsByDate[date] ?? [] }

    public func addEvent(date: String, event: Event) {
        var e = event; e.date = date
        do {
            try db.saveEvent(e)
            eventsByDate[date, default: []].append(e)
        } catch {
            print("[EventService] Error adding event:", error)
        }
    }

    public func updateEvent(date: String, event: Event) {
        var e = event; e.date = date
        do {
            try db.saveEvent(e)
            eventsByDate[date] = (eventsByDate[date] ?? []).map { $0.id == e.id ? e : $0 }
        } catch {
            print("[EventService] Error updating event:", error)
        }
    }

    public func deleteEvent(date: String, id: String) {
        do {
            try db.deleteEvent(id: id)
            let list = (eventsByDate[date] ?? []).filter { $0.id != id }
            if list.isEmpty { eventsByDate.removeValue(forKey: date) } else { eventsByDate[date] = list }
        } catch {
            print("[EventService] Error deleting event:", error)
        }
    }

    /// Re-dates an event and moves it between date buckets.
    public func moveEvent(oldDate: String, newDate: String, id: String) {
        guard var event = (eventsByDate[oldDate] ?? []).first(where: { $0.id == id }) else { return }
        event.date = newDate
        do {
            try db.saveEvent(event)
            let oldList = (eventsByDate[oldDate] ?? []).filter { $0.id != id }
            if oldList.isEmpty { eventsByDate.removeValue(forKey: oldDate) } else { eventsByDate[oldDate] = oldList }
            eventsByDate[newDate, default: []].append(event)
        } catch {
            print("[EventService] Error moving event:", error)
        }
    }
}
