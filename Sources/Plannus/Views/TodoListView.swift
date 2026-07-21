import SwiftUI

/// The standalone flat to-do list (Tasks tab). Ports `screens/TaskScreen.tsx`
/// (FUNCTIONALITY.md §6): add trimmed items, swipe to delete.
struct TodoListView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var newTodo = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(Array(store.todos.enumerated()), id: \.offset) { _, item in
                        Text(item)
                    }
                    .onDelete { store.deleteTodos(at: $0) }
                }
                .listStyle(.plain)
                .overlay {
                    if store.todos.isEmpty {
                        Text("No to-dos yet")
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack {
                    TextField("New todo", text: $newTodo)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add)
                }
                .padding()
            }
            .navigationTitle("To-Do")
        }
    }

    private func add() {
        store.addTodo(newTodo)
        newTodo = ""
    }
}

#Preview {
    TodoListView()
        .environmentObject(TodoStore(store: InMemoryStore()))
}
