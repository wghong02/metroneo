import SwiftUI

/// The primary feature: a native graphical calendar plus the per-date task list,
/// with add / edit / delete. Ports `screens/CalendarScreen.tsx` (FUNCTIONALITY.md §4).
struct CalendarView: View {
    @EnvironmentObject private var store: TaskStore

    @State private var selectedDate = Date()
    @State private var editing: EditTarget?

    /// Identifies an in-progress add or edit for the presented sheet.
    private struct EditTarget: Identifiable {
        let id = UUID()
        /// Index being edited, or nil for a new task.
        let index: Int?
        let task: Task?
    }

    private var dateKey: String { TimeUtilities.dateKey(for: selectedDate) }
    private var items: [Task] { store.tasks(on: dateKey) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Native SwiftUI calendar.
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Divider()

                taskList
            }
            .navigationTitle("Tasks for \(dateKey)")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = EditTarget(index: nil, task: nil)
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { target in
                NewTaskSheet(
                    initialTitle: target.task?.title ?? "",
                    initialTime: target.task?.time ?? "09:00",
                    initialNotes: target.task?.notes ?? ""
                ) { title, time, notes in
                    store.saveTask(
                        date: dateKey,
                        title: title,
                        time: time,
                        notes: notes,
                        editIndex: target.index
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var taskList: some View {
        if items.isEmpty {
            Spacer()
            Text("No tasks yet")
                .italic()
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                    Button {
                        editing = EditTarget(index: index, task: task)
                    } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.deleteTask(date: dateKey, index: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

/// A single task row: formatted time badge + title.
private struct TaskRow: View {
    let task: Task

    var body: some View {
        HStack(spacing: 12) {
            Text(TimeUtilities.formatTime(task.time))
                .font(.subheadline.bold())
                .frame(width: 80, alignment: .leading)
                .padding(8)
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.subheadline.bold())
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private extension View {
    /// Inline title on iOS; no-op elsewhere (macOS has no equivalent modifier).
    @ViewBuilder
    func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

#Preview {
    CalendarView()
        .environmentObject(TaskStore(store: InMemoryStore()))
}
