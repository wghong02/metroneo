import SwiftUI

/// Create/edit a task with its full field set (FUNCTIONALITY.md §7.1).
struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: Task?
    let onSave: (Task) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var priority: Double
    @State private var performance: Double
    @State private var createDate: Date
    @State private var deadlineDate: Date
    @State private var useDeadlineTime: Bool
    @State private var deadlineTime: Date
    @State private var recurring: Bool
    @State private var frequencyPattern: FrequencyPattern
    @State private var frequencyCount: Int
    @State private var estimatedDuration: String
    @State private var types: [String]
    @State private var newType: String
    @State private var subTasks: [SubTask]
    @State private var newSubTaskTitle: String
    @State private var newSubTaskNotes: String

    init(task: Task?, onSave: @escaping (Task) -> Void) {
        self.existing = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _priority = State(initialValue: Double(task?.priorityRating ?? 50))
        _performance = State(initialValue: Double(task?.performanceRating ?? 50))
        _createDate = State(initialValue: task?.createDate ?? Date())
        let deadline = task?.deadline
        _deadlineDate = State(initialValue: deadline ?? Date())
        let hasTime = task?.hasDeadlineTime ?? false
        _useDeadlineTime = State(initialValue: hasTime)
        _deadlineTime = State(initialValue: hasTime ? (deadline ?? Date()) : DateTimeUtilities.time(hour: 23, minute: 59))
        _recurring = State(initialValue: task?.recurring ?? false)
        _frequencyPattern = State(initialValue: task?.frequencyPattern ?? .none)
        _frequencyCount = State(initialValue: task?.frequencyCount ?? 1)
        _estimatedDuration = State(initialValue: task?.estimatedDuration.map(String.init) ?? "")
        _types = State(initialValue: task?.types ?? [])
        _newType = State(initialValue: "")
        _subTasks = State(initialValue: task?.subTasks ?? [])
        _newSubTaskTitle = State(initialValue: "")
        _newSubTaskNotes = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Description") {
                    TextField("Task title", text: $title)
                }

                Section("Ratings") {
                    sliderRow("Priority", value: $priority)
                    sliderRow("Performance", value: $performance)
                }

                Section("Schedule") {
                    DatePicker("Create Date", selection: $createDate, displayedComponents: .date)
                    DatePicker("Deadline", selection: $deadlineDate, displayedComponents: .date)
                    Toggle("Set deadline time", isOn: $useDeadlineTime)
                    if useDeadlineTime {
                        DatePicker("Time", selection: $deadlineTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Recurrence") {
                    Toggle("Recurring Task", isOn: $recurring)
                    if recurring {
                        Picker("Frequency", selection: $frequencyPattern) {
                            ForEach(FrequencyPattern.allCases, id: \.self) { pattern in
                                Text(pattern.rawValue.capitalized).tag(pattern)
                            }
                        }
                        Stepper("Frequency Count: \(frequencyCount)", value: $frequencyCount, in: 1...365)
                    }
                }

                Section("Estimated Duration (min)") {
                    TextField("60", text: $estimatedDuration)
                        .keyboardType(.numberPad)
                }

                Section("Task Types") {
                    HStack {
                        TextField("Add task type...", text: $newType)
                        Button("Add") { addType() }.disabled(newType.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !types.isEmpty {
                        HStack {
                            ForEach(types, id: \.self) { type in
                                Button {
                                    types.removeAll { $0 == type }
                                } label: {
                                    Label(type, systemImage: "xmark.circle.fill").labelStyle(.titleAndIcon)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                Section("Subtasks") {
                    TextField("Subtask title...", text: $newSubTaskTitle)
                    TextField("Subtask notes...", text: $newSubTaskNotes)
                    Button("Add Subtask") { addSubTask() }
                        .disabled(newSubTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    ForEach(subTasks) { sub in
                        Text("• \(sub.title)")
                    }
                    .onDelete { subTasks.remove(atOffsets: $0) }
                }

                Section("Notes") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle(existing == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.bold) }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue))").foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 1)
        }
    }

    private func addType() {
        let trimmed = newType.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !types.contains(trimmed) else { return }
        types.append(trimmed)
        newType = ""
    }

    private func addSubTask() {
        let trimmed = newSubTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subTasks.append(SubTask(
            title: trimmed,
            notes: newSubTaskNotes.isEmpty ? nil : newSubTaskNotes,
            deadline: DateTimeUtilities.endOfDay(deadlineDate),
            priorityRating: 50,
            performanceRating: 50,
            order: subTasks.count
        ))
        newSubTaskTitle = ""
        newSubTaskNotes = ""
    }

    private func save() {
        let safeTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : title
        let deadline = useDeadlineTime
            ? DateTimeUtilities.combine(day: deadlineDate, time: deadlineTime)
            : DateTimeUtilities.endOfDay(deadlineDate)
        let task = Task(
            id: existing?.id,
            title: safeTitle,
            notes: notes.trimmingCharacters(in: .whitespaces),
            deadline: deadline,
            hasDeadlineTime: useDeadlineTime,
            priorityRating: Int(priority),
            performanceRating: Int(performance),
            completedAt: existing?.completedAt,
            createDate: createDate,
            frequencyPattern: recurring ? frequencyPattern : .none,
            frequencyCount: frequencyCount,
            recurring: recurring,
            types: types.isEmpty ? nil : types,
            estimatedDuration: Int(estimatedDuration),
            actualDuration: existing?.actualDuration,
            performanceNotes: existing?.performanceNotes,
            subTasks: subTasks.enumerated().map { index, sub in
                var s = sub; s.order = index; return s
            }
        )
        onSave(task)
        dismiss()
    }
}
