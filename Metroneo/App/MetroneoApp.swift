import SwiftUI

/// App entry point. Boots the SwiftData store and shares the services through
/// the environment (FUNCTIONALITY.md §10).
@main
struct MetroneoApp: App {
    @StateObject private var taskService: TaskService
    @StateObject private var eventService: EventService
    @StateObject private var preferences = PerformancePreferencesService()

    @Environment(\.scenePhase) private var scenePhase

    /// Kept so admin actions (stats/erase) in Settings can reach the DB.
    private let database: SwiftDataDatabase

    init() {
        // A failure to open the on-disk store is fatal — no silent fallback.
        let db = try! SwiftDataDatabase()
        self.database = db
        _taskService = StateObject(wrappedValue: TaskService(db: db))
        _eventService = StateObject(wrappedValue: EventService(db: db))
    }

    var body: some Scene {
        WindowGroup {
            RootView(database: database)
                .environmentObject(taskService)
                .environmentObject(eventService)
                .environmentObject(preferences)
                .onAppear {
                    taskService.loadTasks()
                    eventService.loadEvents()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Safety net: flush unsaved task edits when the app leaves the
            // foreground (events already persist immediately).
            if phase == .background, taskService.hasUnsavedChanges {
                taskService.save()
            }
        }
    }
}
