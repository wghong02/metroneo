import SwiftUI

/// Tasks tab: Upcoming/Completed toggle, task cards with completion, subtasks,
/// and performance rating. Ports `screens/TaskScreen.tsx` (FUNCTIONALITY.md §7).
struct TaskListView: View {
    @EnvironmentObject private var tasks: TaskService
    @EnvironmentObject private var preferences: PerformancePreferencesService

    @State private var showCompleted = false
    @State private var editingTask: Task?
    @State private var creatingTask = false
    @State private var ratingTarget: RatingTarget?
    @State private var blockedAlert = false

    private struct RatingTarget: Identifiable {
        let id = UUID()
        let task: Task
        /// When true, saving also marks the task complete.
        let completing: Bool
    }

    private var upcoming: [Task] {
        tasks.tasks.filter { !$0.isCompleted }
            .sorted { deadlineDate($0) < deadlineDate($1) }
    }
    private var completed: [Task] {
        tasks.tasks.filter { $0.isCompleted }
            .sorted { $0.completedAt > $1.completedAt }
    }
    private var current: [Task] { showCompleted ? completed : upcoming }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    ForEach(current) { task in
                        TaskCard(
                            task: task,
                            preferences: preferences,
                            onToggleComplete: { toggleCompletion(task) },
                            onToggleSubTask: { sub in
                                if let tid = task.id, let sid = sub.id {
                                    tasks.toggleSubTask(taskId: tid, subTaskId: sid)
                                }
                            },
                            onEdit: { editingTask = task },
                            onEditRating: {
                                if task.isCompleted { ratingTarget = RatingTarget(task: task, completing: false) }
                            }
                        )
                        .swipeActions {
                            Button(role: .destructive) {
                                if let id = task.id { tasks.deleteTask(id: id) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)

                Button {
                    creatingTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .frame(width: 56, height: 56)
                        .background(Color.blue, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                .padding(24)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $showCompleted) {
                        Text("Upcoming (\(upcoming.count))").tag(false)
                        Text("Completed (\(completed.count))").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .sheet(isPresented: $creatingTask) {
                TaskEditorSheet(task: nil) { tasks.addTask($0) }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task) { tasks.updateTask($0) }
            }
            .sheet(item: $ratingTarget) { target in
                PerformanceRatingSheet(task: target.task) { rating, notes in
                    guard let id = target.task.id else { return }
                    tasks.updateTaskPerformance(id: id, performance: rating, notes: notes)
                    if target.completing { tasks.completeTask(id: id) }
                }
            }
            .alert("Cannot Complete Task", isPresented: $blockedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All subtasks must be completed before marking the main task as complete.")
            }
        }
    }

    private func toggleCompletion(_ task: Task) {
        guard let id = task.id else { return }
        if task.isCompleted {
            tasks.uncompleteTask(id: id)
        } else {
            if task.subTasks.contains(where: { !$0.isCompleted }) {
                blockedAlert = true
            } else {
                ratingTarget = RatingTarget(task: task, completing: true)
            }
        }
    }

    private func deadlineDate(_ task: Task) -> String {
        task.deadline.split(separator: "T").first.map(String.init) ?? task.deadline
    }
}

/// A task card showing checkbox, title, ratings, meta, and subtask preview.
private struct TaskCard: View {
    let task: Task
    let preferences: PerformancePreferencesService
    let onToggleComplete: () -> Void
    let onToggleSubTask: (SubTask) -> Void
    let onEdit: () -> Void
    let onEditRating: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                }
                .buttonStyle(.plain)

                Spacer()
                VStack(alignment: .trailing) {
                    Text("Priority: \(task.priorityRating)").font(.caption2).foregroundStyle(.secondary)
                    Text("Performance: \(task.performanceRating)/100").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let notes = task.notes, !notes.isEmpty {
                Text(notes).font(.caption).italic().foregroundStyle(.secondary)
            }

            Text("Created: \(DateTimeUtilities.localizedDate(fromKey: task.createDate)) | Deadline: \(DateTimeUtilities.formatDeadline(task.deadline))")
                .font(.caption2).foregroundStyle(.secondary)

            if let types = task.types, !types.isEmpty {
                HStack {
                    ForEach(types, id: \.self) { type in
                        Text(type)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "#E3F2FD"), in: Capsule())
                            .foregroundStyle(Color(hex: "#1976D2"))
                    }
                }
            }

            if !task.subTasks.isEmpty {
                Divider()
                Text("Subtasks (\(task.subTasks.count))").font(.caption2.bold()).foregroundStyle(.secondary)
                ForEach(task.subTasks.prefix(2)) { sub in
                    HStack {
                        Button { onToggleSubTask(sub) } label: {
                            Image(systemName: sub.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundStyle(.blue).font(.caption)
                        }
                        .buttonStyle(.plain)
                        Text("• \(sub.title)")
                            .font(.caption)
                            .strikethrough(sub.isCompleted)
                            .foregroundStyle(sub.isCompleted ? .secondary : .primary)
                    }
                }
                if task.subTasks.count > 2 {
                    Text("+\(task.subTasks.count - 2) more").font(.caption2).italic().foregroundStyle(.secondary)
                }
            }

            if task.isCompleted {
                Text("Completed: \(DateTimeUtilities.localizedDate(fromKey: task.completedAt))")
                    .font(.caption2).italic().foregroundStyle(.secondary)
                if let pnotes = task.performanceNotes, !pnotes.isEmpty {
                    Text("Performance Notes: \(pnotes)").font(.caption2).italic().foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        // Long-press a completed task to edit its rating.
        .onLongPressGesture { onEditRating() }
    }
}
