import SwiftUI

/// Create/edit an event (FUNCTIONALITY.md §6.1).
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
        _startTime = State(initialValue: event?.startTime ?? DateTimeUtilities.time(hour: 8, minute: 0))
        _endTime = State(initialValue: event?.endTime ?? DateTimeUtilities.time(hour: 9, minute: 0))
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
            date: existing?.date ?? Date(),
            title: title,
            notes: notes.isEmpty ? nil : notes,
            allDay: allDay,
            startTime: allDay ? nil : startTime,
            endTime: allDay ? nil : endTime
        )
        onSave(event)
        dismiss()
    }
}
