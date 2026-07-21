import SwiftUI

/// Create/edit an event. Ports `components/modals/NewEventModal.tsx`
/// (FUNCTIONALITY.md §6.1).
struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: Event?
    let onSave: (Event) -> Void

    @State private var title: String
    @State private var allDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String

    init(event: Event?, onSave: @escaping (Event) -> Void) {
        self.existing = event
        self.onSave = onSave
        _title = State(initialValue: event?.title ?? "New Event")
        _allDay = State(initialValue: event?.allDay ?? false)
        _startTime = State(initialValue: Self.time(from: event?.startTime) ?? Self.defaultTime(8))
        _endTime = State(initialValue: Self.time(from: event?.endTime) ?? Self.defaultTime(9))
        _notes = State(initialValue: event?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("Description", text: $title)
                }
                Section {
                    Toggle("All Day", isOn: $allDay)
                    if !allDay {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section("Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle(existing == nil ? "New Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
        }
    }

    private func save() {
        // Empty title just closes (matches original).
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { dismiss(); return }
        let event = Event(
            id: existing?.id ?? Event.makeID(),
            date: existing?.date ?? DateTimeUtilities.todayKey(),
            title: title,
            notes: notes.isEmpty ? nil : notes,
            allDay: allDay,
            startTime: allDay ? nil : Self.hhmm(from: startTime),
            endTime: allDay ? nil : Self.hhmm(from: endTime)
        )
        onSave(event)
        dismiss()
    }

    // MARK: - Time conversion

    private static func time(from hhmm: String?) -> Date? {
        guard let hhmm else { return nil }
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
    }

    private static func defaultTime(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static func hhmm(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
