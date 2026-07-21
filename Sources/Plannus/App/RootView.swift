import SwiftUI

/// Bottom tab bar with the app's four destinations (FUNCTIONALITY.md §1, §7).
struct RootView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            TodoListView()
                .tabItem { Label("Tasks", systemImage: "list.bullet") }

            PerformanceView()
                .tabItem { Label("Performance", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.blue) // matches the original #007AFF active tint
    }
}

#Preview {
    RootView()
        .environmentObject(TaskStore(store: InMemoryStore()))
        .environmentObject(TodoStore(store: InMemoryStore()))
}
