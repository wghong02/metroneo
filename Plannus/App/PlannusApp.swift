import SwiftUI

/// App entry point. Boots the Core Data database and shares the services through
/// the environment (FUNCTIONALITY.md §10).
@main
struct PlannusApp: App {
    @StateObject private var taskService: TaskService
    @StateObject private var eventService: EventService
    @StateObject private var preferences = PerformancePreferencesService()

    /// Kept so admin actions (stats/erase) in Settings can reach the DB.
    private let database: TaskDatabase

    init() {
        // Fall back to an in-memory store if Core Data fails to load, so the app
        // still runs (matching the RN app's non-fatal init behavior).
        let db: TaskDatabase = (try? CoreDataDatabase()) ?? InMemoryDatabase()
        try? db.initialize()
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
    }
}
