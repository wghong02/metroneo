import SwiftUI

/// Calendar tab: native graphical calendar + per-date list of events and the
/// incomplete tasks due that day. Ports `screens/CalendarScreen.tsx`
/// (FUNCTIONALITY.md §6).
struct CalendarView: View {
    @EnvironmentObject private var events: EventService
    @EnvironmentObject private var tasks: TaskService

    @State private var selectedDate = Date()
    @State private var editingEvent: EventTarget?

    private struct EventTarget: Identifiable {
        let id = UUID()
        let event: Event?
    }

    private var dateKey: String { DateTimeUtilities.dateKey(for: selectedDate) }
    private var dayEvents: [Event] { events.events(on: dateKey) }
    private var incompleteTasks: [Task] {
        DateTimeUtilities.incompleteTasks(tasks.tasks, forDate: dateKey)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                Divider()

                List {
                    Section("Events & Tasks for \(dateKey)") {
                        if dayEvents.isEmpty && incompleteTasks.isEmpty {
                            Text("No events or tasks yet")
                                .italic().foregroundStyle(.secondary)
                        }
                        ForEach(dayEvents) { event in
                            EventRow(event: event)
                                .contentShape(Rectangle())
                                .onTapGesture { editingEvent = EventTarget(event: event) }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        events.deleteEvent(date: dateKey, id: event.id)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                        ForEach(incompleteTasks) { task in
                            CalendarTaskRow(task: task)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingEvent = EventTarget(event: nil)
                    } label: { Label("Add Event", systemImage: "plus") }
                }
            }
            .sheet(item: $editingEvent) { target in
                EventEditorSheet(event: target.event) { result in
                    if let existing = target.event {
                        var updated = result; updated.id = existing.id
                        events.updateEvent(date: dateKey, event: updated)
                    } else {
                        events.addEvent(date: dateKey, event: result)
                    }
                }
            }
        }
    }
}

/// An event row: title + start/end time.
private struct EventRow: View {
    let event: Event
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.subheadline.bold())
                if event.allDay {
                    Text("All day").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                if let start = event.startTime {
                    Text(DateTimeUtilities.formatTime(start)).font(.caption.bold())
                }
                if let end = event.endTime {
                    Text(DateTimeUtilities.formatTime(end)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A read-only task row shown on the calendar (distinct styling).
private struct CalendarTaskRow: View {
    let task: Task
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.title).font(.subheadline.bold())
            Text("Deadline: \(DateTimeUtilities.formatDeadline(task.deadline))")
                .font(.caption).foregroundStyle(.red)
            if let notes = task.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
            Text("Priority: \(task.priorityRating)")
                .font(.caption.bold()).foregroundStyle(.blue)
        }
        .listRowBackground(Color(hex: "#FFF3CD"))
    }
}
