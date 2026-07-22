import Foundation
import OSLog

/// Shared unified logging, replacing ad-hoc `print` in the services. Keeps the
/// `OSLog` dependency contained to this file — call sites pass plain strings.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Metroneo"
    private static let tasks = Logger(subsystem: subsystem, category: "TaskService")
    private static let events = Logger(subsystem: subsystem, category: "EventService")

    static func taskError(_ message: String) { tasks.error("\(message, privacy: .public)") }
    static func eventError(_ message: String) { events.error("\(message, privacy: .public)") }
}
