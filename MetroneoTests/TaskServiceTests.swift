import XCTest
@testable import Metroneo

final class TaskServiceTests: XCTestCase {
    private func makeDB() -> SwiftDataDatabase { try! SwiftDataDatabase(inMemory: true) }

    private func sampleTask(_ title: String = "Write") -> Task {
        Task(title: title, deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20"))
    }

    func testAddPersistsImmediately() {
        let db = makeDB()
        let s = TaskService(db: db)
        s.addTask(sampleTask())
        // A fresh service on the same store sees it — no manual save step.
        XCTAssertEqual(TaskService(db: db).loadTasks().map(\.title), ["Write"])
    }

    func testCompletionAndRatingPersistAndIDsStay() {
        let db = makeDB()
        let s = TaskService(db: db)
        s.addTask(sampleTask())
        let id = s.tasks[0].id!

        // Two edits against the same captured id — both must land on one task.
        s.updateTaskPerformance(id: id, performance: 85, notes: "good")
        s.completeTask(id: id)

        let reloaded = TaskService(db: db)
        reloaded.loadTasks()
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.tasks[0].id, id, "id must survive mutations")
        XCTAssertTrue(reloaded.tasks[0].isCompleted)
        XCTAssertEqual(reloaded.tasks[0].performanceRating, 85)
    }

    func testDeletePersists() {
        let db = makeDB()
        let s = TaskService(db: db)
        s.addTask(sampleTask())
        s.deleteTask(id: s.tasks[0].id!)
        XCTAssertTrue(s.tasks.isEmpty)
        XCTAssertTrue(TaskService(db: db).loadTasks().isEmpty)
    }

    func testBlankTitleDefaults() {
        let s = TaskService(db: makeDB())
        s.addTask(Task(title: "   ", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20")))
        XCTAssertEqual(s.tasks[0].title, "New Task")
    }

    func testToggleSubTask() {
        let s = TaskService(db: makeDB())
        s.addTask(Task(title: "Parent", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20"),
                       subTasks: [SubTask(title: "child")]))
        let tid = s.tasks[0].id!
        let sid = s.tasks[0].subTasks[0].id!
        s.toggleSubTask(taskId: tid, subTaskId: sid)
        XCTAssertTrue(s.tasks[0].subTasks[0].isCompleted)
    }

    func testUpdateTaskReplacesMatchingID() {
        let s = TaskService(db: makeDB())
        s.addTask(sampleTask("Old"))
        let id = s.tasks[0].id!
        var edited = s.tasks[0]
        edited.title = "New"
        s.updateTask(edited)
        XCTAssertEqual(s.tasks.count, 1)
        XCTAssertEqual(s.tasks[0].id, id)
        XCTAssertEqual(s.tasks[0].title, "New")
    }

    func testUncompleteClearsCompletion() {
        let s = TaskService(db: makeDB())
        s.addTask(sampleTask())
        let id = s.tasks[0].id!
        s.completeTask(id: id)
        XCTAssertTrue(s.tasks[0].isCompleted)
        s.uncompleteTask(id: id)
        XCTAssertFalse(s.tasks[0].isCompleted)
    }

    func testAddAssignsSubtaskOrderAndParent() {
        let s = TaskService(db: makeDB())
        s.addTask(Task(title: "P", deadline: DateTimeUtilities.endOfDay(day("2026-07-21")), createDate: day("2026-07-20"),
                       subTasks: [SubTask(title: "a"), SubTask(title: "b"), SubTask(title: "c")]))
        let t = s.tasks[0]
        XCTAssertEqual(t.subTasks.map(\.order), [0, 1, 2])
        XCTAssertTrue(t.subTasks.allSatisfy { $0.parentTaskId == t.id })
        XCTAssertTrue(t.subTasks.allSatisfy { $0.id != nil })
    }
}
