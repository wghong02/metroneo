import SwiftUI

/// App entry point. Owns the two stores and injects them into the view tree.
@main
struct PlannusApp: App {
    @StateObject private var taskStore = TaskStore()
    @StateObject private var todoStore = TodoStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(taskStore)
                .environmentObject(todoStore)
        }
    }
}
