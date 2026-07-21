import SwiftUI

/// Bottom-sheet form for creating or editing a scheduled task. Ports
/// `components/NewTaskModal.tsx` (FUNCTIONALITY.md §5).
struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    let titleLabel: String
    let onSave: (_ title: String, _ time: String, _ notes: String) -> Void

    @State private var title: String
    @State private var selectedTime: String
    @State private var notes: String

    private let timeOptions = TimeUtilities.generateTimeOptions()

    init(
        initialTitle: String = "",
        initialTime: String = "09:00",
        initialNotes: String = "",
        titleLabel: String = "Task Description",
        onSave: @escaping (String, String, String) -> Void
    ) {
        self.titleLabel = titleLabel
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _selectedTime = State(initialValue: initialTime)
        _notes = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(titleLabel) {
                    TextField(titleLabel, text: $title)
                }

                Section("Time") {
                    // Native dropdown over the 48 preset half-hour slots.
                    Picker("Time", selection: $selectedTime) {
                        ForEach(timeOptions, id: \.self) { option in
                            Text(TimeUtilities.formatTime(option)).tag(option)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, selectedTime, notes)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview {
    NewTaskSheet { _, _, _ in }
}
