import SwiftUI

/// Bottom tab bar with the app's four destinations (FUNCTIONALITY.md §1).
struct RootView: View {
    let database: SwiftDataDatabase

    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "list.bullet") }

            PerformanceView()
                .tabItem { Label("Performance", systemImage: "chart.bar") }

            SettingsView(database: database)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.blue)
    }
}
