import Foundation
import CoreData

/// Core Data–backed ``TaskDatabase``. The schema is defined by the
/// `Metroneo.xcdatamodeld` model (entities `CDTask`, `CDSubTask`, `CDEvent`),
/// compiled by Xcode into `Metroneo.momd` inside the app bundle.
///
/// Save semantics (FUNCTIONALITY.md §3): `saveTasks` replaces the entire task +
/// subtask set inside one save; ids are (re)generated on insert and coerced to
/// strings.
public final class CoreDataDatabase: TaskDatabase {
    private let container: NSPersistentContainer
    private var context: NSManagedObjectContext { container.viewContext }

    /// - Parameter inMemory: when true, uses an in-memory store (previews/tests).
    public init(inMemory: Bool = false) throws {
        // The compiled `Metroneo.momd` lives in the app's main bundle; build the
        // container from the merged model there (with automatic-lookup fallback).
        if let model = NSManagedObjectModel.mergedModel(from: [Bundle.main]) {
            container = NSPersistentContainer(name: "Metroneo", managedObjectModel: model)
        } else {
            container = NSPersistentContainer(name: "Metroneo")
        }
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw MetroneoError.database("Failed to load store: \(loadError)") }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public func initialize() throws { /* stores are loaded in init */ }

    public func reset() throws {
        for entity in ["CDSubTask", "CDTask", "CDEvent"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(delete)
        }
        context.reset()
    }

    public func stats() -> DatabaseStats {
        func count(_ entity: String) -> Int {
            (try? context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entity))) ?? 0
        }
        return DatabaseStats(
            taskCount: count("CDTask"),
            subTaskCount: count("CDSubTask"),
            eventCount: count("CDEvent"),
            settingCount: 0,
            schemaVersion: 1,
            isClosed: false
        )
    }

    // MARK: - Tasks

    public func loadTasks() throws -> [Task] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDTask")
        request.sortDescriptors = [NSSortDescriptor(key: "createDate", ascending: false)]
        return try context.fetch(request).map(task(from:))
    }

    public func saveTasks(_ tasks: [Task]) throws {
        // Replace the whole set (delete-all + re-insert), matching the RN layer.
        try reset()
        var seq = 1
        for task in tasks {
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDTask", into: context)
            let taskID = String(seq); seq += 1
            row.setValue(taskID, forKey: "taskID")
            row.setValue(task.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Task" : task.title, forKey: "title")
            row.setValue(task.notes, forKey: "notes")
            row.setValue(task.deadline, forKey: "deadline")
            row.setValue(Int32(task.priorityRating), forKey: "priorityRating")
            row.setValue(Int32(task.performanceRating), forKey: "performanceRating")
            row.setValue(task.completedAt, forKey: "completedAt")
            row.setValue(task.createDate, forKey: "createDate")
            row.setValue(task.frequencyPattern.rawValue, forKey: "frequencyPattern")
            row.setValue(Int32(task.frequencyCount), forKey: "frequencyCount")
            row.setValue(task.recurring, forKey: "recurring")
            row.setValue(encodeTypes(task.types), forKey: "typesJSON")
            row.setValue(Int64(task.estimatedDuration ?? -1), forKey: "estimatedDuration")
            row.setValue(Int64(task.actualDuration ?? -1), forKey: "actualDuration")
            row.setValue(task.performanceNotes, forKey: "performanceNotes")

            var subRows = Set<NSManagedObject>()
            for (index, sub) in task.subTasks.enumerated() {
                let subRow = NSEntityDescription.insertNewObject(forEntityName: "CDSubTask", into: context)
                subRow.setValue(String(seq), forKey: "subTaskID"); seq += 1
                subRow.setValue(sub.title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Subtask" : sub.title, forKey: "title")
                subRow.setValue(sub.notes, forKey: "notes")
                subRow.setValue(sub.deadline, forKey: "deadline")
                subRow.setValue(Int32(sub.priorityRating), forKey: "priorityRating")
                subRow.setValue(Int32(sub.performanceRating), forKey: "performanceRating")
                subRow.setValue(sub.completedAt, forKey: "completedAt")
                subRow.setValue(Int32(index), forKey: "orderIndex")
                subRow.setValue(row, forKey: "parentTask")
                subRows.insert(subRow)
            }
            row.setValue(subRows as NSSet, forKey: "subTasks")
        }
        try saveContext()
    }

    // MARK: - Events

    public func loadEvents() throws -> [Event] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDEvent")
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "startTime", ascending: true),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return try context.fetch(request).map(event(from:))
    }

    public func saveEvent(_ event: Event) throws {
        guard !event.title.isEmpty else {
            throw MetroneoError.validation("Event title is required")
        }
        let row = try fetchEventRow(id: event.id) ?? NSEntityDescription.insertNewObject(forEntityName: "CDEvent", into: context)
        row.setValue(event.id, forKey: "eventID")
        row.setValue(event.date, forKey: "date")
        row.setValue(event.title, forKey: "title")
        row.setValue(event.notes, forKey: "notes")
        row.setValue(event.allDay, forKey: "allDay")
        row.setValue(event.startTime, forKey: "startTime")
        row.setValue(event.endTime, forKey: "endTime")
        try saveContext()
    }

    public func deleteEvent(id: String) throws {
        if let row = try fetchEventRow(id: id) {
            context.delete(row)
            try saveContext()
        }
    }

    public func event(id: String) throws -> Event? {
        try fetchEventRow(id: id).map(event(from:))
    }

    public func events(forDate date: Date) throws -> [Event] {
        let start = DateTimeUtilities.startOfDay(date)
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDEvent")
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                        start as NSDate,
                                        start.addingTimeInterval(86_400) as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "startTime", ascending: true),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return try context.fetch(request).map(event(from:))
    }

    // MARK: - Row mapping

    private func fetchEventRow(id: String) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDEvent")
        request.predicate = NSPredicate(format: "eventID == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do { try context.save() } catch { throw MetroneoError.database("Save failed: \(error)") }
    }

    private func task(from row: NSManagedObject) -> Task {
        let subs = (row.value(forKey: "subTasks") as? Set<NSManagedObject> ?? [])
            .map(subTask(from:))
            .sorted { $0.order < $1.order }
        return Task(
            id: row.value(forKey: "taskID") as? String,
            title: row.value(forKey: "title") as? String ?? "Untitled Task",
            notes: row.value(forKey: "notes") as? String,
            deadline: row.value(forKey: "deadline") as? Date ?? Date(),
            priorityRating: Int(row.value(forKey: "priorityRating") as? Int32 ?? 0),
            performanceRating: Int(row.value(forKey: "performanceRating") as? Int32 ?? 0),
            completedAt: row.value(forKey: "completedAt") as? Date,
            createDate: row.value(forKey: "createDate") as? Date ?? Date(),
            frequencyPattern: FrequencyPattern(rawValue: row.value(forKey: "frequencyPattern") as? String ?? "none") ?? .none,
            frequencyCount: Int(row.value(forKey: "frequencyCount") as? Int32 ?? 0),
            recurring: row.value(forKey: "recurring") as? Bool ?? false,
            types: decodeTypes(row.value(forKey: "typesJSON") as? String),
            estimatedDuration: nilIfNegative(row.value(forKey: "estimatedDuration") as? Int64),
            actualDuration: nilIfNegative(row.value(forKey: "actualDuration") as? Int64),
            performanceNotes: row.value(forKey: "performanceNotes") as? String,
            subTasks: subs
        )
    }

    private func subTask(from row: NSManagedObject) -> SubTask {
        SubTask(
            id: row.value(forKey: "subTaskID") as? String,
            title: row.value(forKey: "title") as? String ?? "Untitled Subtask",
            notes: row.value(forKey: "notes") as? String,
            deadline: row.value(forKey: "deadline") as? Date ?? Date(),
            priorityRating: Int(row.value(forKey: "priorityRating") as? Int32 ?? 0),
            performanceRating: Int(row.value(forKey: "performanceRating") as? Int32 ?? 0),
            completedAt: row.value(forKey: "completedAt") as? Date,
            parentTaskId: (row.value(forKey: "parentTask") as? NSManagedObject)?.value(forKey: "taskID") as? String,
            order: Int(row.value(forKey: "orderIndex") as? Int32 ?? 0)
        )
    }

    private func event(from row: NSManagedObject) -> Event {
        Event(
            id: row.value(forKey: "eventID") as? String ?? Event.makeID(),
            date: row.value(forKey: "date") as? Date ?? Date(),
            title: row.value(forKey: "title") as? String ?? "Untitled Event",
            notes: row.value(forKey: "notes") as? String,
            allDay: row.value(forKey: "allDay") as? Bool ?? false,
            startTime: row.value(forKey: "startTime") as? Date,
            endTime: row.value(forKey: "endTime") as? Date
        )
    }

    private func encodeTypes(_ types: [String]?) -> String? {
        guard let types, !types.isEmpty, let data = try? JSONEncoder().encode(types) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeTypes(_ json: String?) -> [String]? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    private func nilIfNegative(_ value: Int64?) -> Int? {
        guard let value, value >= 0 else { return nil }
        return Int(value)
    }
}
