import SwiftUI

/// A 0–100 performance rating slider + optional notes (FUNCTIONALITY.md §7.2).
struct PerformanceRatingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let task: Task
    let onSave: (_ rating: Int, _ notes: String?) -> Void

    @State private var rating: Double
    @State private var notes: String

    init(task: Task, onSave: @escaping (Int, String?) -> Void) {
        self.task = task
        self.onSave = onSave
        _rating = State(initialValue: Double(task.isCompleted ? task.performanceRating : 50))
        _notes = State(initialValue: task.performanceNotes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") { Text(task.title).font(.headline) }
                Section("Performance Rating") {
                    HStack {
                        Text("Rating")
                        Spacer()
                        Text("\(Int(rating))/100").foregroundStyle(.secondary)
                    }
                    Slider(value: $rating, in: 0...100, step: 1)
                }
                Section("Notes") {
                    TextField("How did it go?", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Rate Performance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(Int(rating), notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes)
                        dismiss()
                    } label: { Label("Save", systemImage: "checkmark") }
                        .labelStyle(.iconOnly).fontWeight(.bold)
                }
            }
        }
    }
}
