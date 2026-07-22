# Metroneo — Functionality Reference

Metroneo is a native iOS task/event planner with performance tracking, written in
Swift + SwiftUI and persisted with Core Data. This document catalogs every
functionality in the app, section by section. The source lives under `Metroneo/`;
code comments reference the section numbers here (e.g. "FUNCTIONALITY.md §3").

---

## 1. Overview

Bottom tab bar with four destinations:

| Tab | Purpose |
| --- | --- |
| **Calendar** | Month calendar; per-date list of **events** plus **incomplete tasks** due that day. |
| **Tasks** | Full task manager: create/edit/delete, subtasks, completion with performance rating, Upcoming/Completed toggle. |
| **Performance** | Analytics over completed tasks: period stats, weekly/monthly line charts, insights, recent list. |
| **Settings** | Personal Preferences → Performance Cutoffs; plus database management (test/stats/erase all) **in Debug builds only**. |

There are three persisted domains:

1. **Tasks** (+ **SubTasks**) — the core productivity model.
2. **Events** — date-anchored calendar entries.
3. **Preferences** — performance-rating cutoffs (key/value in `UserDefaults`).

---

## 2. Domain models

### 2.1 Common fields
Every task/subtask/event carries `id: String?`, `title: String`, `notes: String?`.

### 2.2 Task
- `id?` — string; assigned by the store on save.
- `title` — required; defaults to `"New Task"` when blank.
- `notes?`
- `deadline: String` — stored as `"YYYY-MM-DDTHH:mm:ss"`. When the user gives no
  time it defaults to **`T23:59:59`**; with a time it is `T{HH:mm}:00`.
- `priorityRating: Int` — 0–100, default 50.
- `performanceRating: Int` — 0–100, default 50.
- `completedAt: String` — `"YYYY-MM-DD"` when complete, or the sentinel **`"na"`**
  (`kNotCompleted`) when not complete.
- `createDate: String` — `"YYYY-MM-DD"` (local). Required.
- `frequencyPattern` — one of `daily | weekly | monthly | yearly | custom | none`
  (default `none`).
- `frequencyCount: Int` — default 0 (editor default 1).
- `recurring: Bool`.
- `types: [String]?` — freeform tags.
- `estimatedDuration: Int?` (minutes), `actualDuration: Int?`.
- `performanceNotes: String?`.
- `subTasks: [SubTask]`.

### 2.3 SubTask
Same rating/deadline/completion fields as Task, plus:
- `parentTaskId: String?`
- `order: Int` — display order within the parent.

### 2.4 Event
- `id: String` — required.
- `date: String` — `"YYYY-MM-DD"`.
- `allDay: Bool`
- `startTime: String?`, `endTime: String?` — `"HH:mm"`.
- `EventMap = [String: [Event]]` — events grouped by date key.

---

## 3. Persistence

Persistence is abstracted behind the `TaskDatabase` protocol. Two implementations:

- **`CoreDataDatabase`** (production) — backed by the `Metroneo.xcdatamodeld` model
  with entities `CDTask`, `CDSubTask`, `CDEvent`. `CDSubTask` has a
  cascade-delete relationship to its parent `CDTask`.
- **`InMemoryDatabase`** — used by tests and previews.

Operations (`TaskDatabase`):

- **Tasks** — `saveTasks(tasks)` replaces the entire task + subtask set in one
  save (delete-all then insert), applying defaults/validation (blank title →
  `"New Task"`); the store assigns string ids and per-parent subtask `order`.
  `loadTasks()` returns tasks ordered by `createDate` descending, each with its
  subtasks ordered by `order`.
- **Events** — `saveEvent(event)` upserts a single event; `deleteEvent(id)`,
  `event(id:)`, `events(forDate:)`, and `loadEvents()` (ordered by date, then
  start time, then title). `title` and `date` are required.
- **Admin** — `initialize()`, `reset()` (clears all data), and `stats()`
  (row counts + connection state).

---

## 4. Services

`TaskService`, `EventService`, and `PerformancePreferencesService` are
`ObservableObject`s injected through the SwiftUI environment; they cache state and
delegate persistence to a `TaskDatabase` (or `UserDefaults` for preferences).

### 4.1 TaskService
Caches the task list and persists by re-saving the whole list.
- `loadTasks()`, `saveTasks(tasks)`
- `addTask(task)` — title defaults to `"New Task"`, notes trimmed; appends.
- `updateTask(updated)` — replaces the task with matching `id`.
- `deleteTask(id)` — removes by id.
- `completeTask(id)` — sets `completedAt` to today (`YYYY-MM-DD`).
- `uncompleteTask(id)` — sets `completedAt` back to `"na"`.
- `updateTaskPriority(id, priority)`.
- `updateTaskPerformance(id, performance, notes?)` — sets `performanceRating`
  (and `performanceNotes`).
- `toggleSubTask(taskId, subTaskId)` — flips a subtask's `completedAt`.

### 4.2 EventService
Caches events grouped by date (`[date: [Event]]`).
- `loadEvents()` — loads all, groups by `date`.
- `addEvent(date, event)` — forces `event.date = date`, upserts, updates cache.
- `updateEvent(date, event)` — upsert + cache replace by id.
- `deleteEvent(date, id)` — delete + cache prune (drops the date key when empty).
- `moveEvent(oldDate, newDate, id)` — re-dates an event and moves it between
  cache buckets.
- `events(on: date)` — cached lookup for a date.

### 4.3 PerformancePreferencesService
Stores `PerformanceCutoffs { fair, good, veryGood, excellent }` in `UserDefaults`
under `@performance_cutoffs`.
- **Defaults: `fair 60, good 75, veryGood 80, excellent 90`.**
- `getCutoffs()` / `cutoffs`, `setCutoffs(c)`, `resetToDefaults()`.
- `text(for:)` → `Excellent | Very Good | Good | Fair | Poor`
  (Poor is anything below `fair`).
- `color(for:)` → hex: Excellent `#2E7D32`, Very Good `#4CAF50`, Good `#2196F3`,
  Fair `#FF9800`, Poor `#F44336`.

---

## 5. Utility functions (`DateTimeUtilities`)

- **`formatTime("HH:mm")`** → 12-hour `"h:mm AM/PM"` (hour 0→12, >12 subtract 12).
- **`formatDeadline("YYYY-MM-DD[THH:mm:ss]")`** → localized date, and if a time
  part is present, `"<date> at <formatTime(HH:mm)>"`.
- **`incompleteTasks(_:forDate:)`** → tasks whose `completedAt` is `"na"` and
  whose deadline **date part** equals `targetDate` (exact day).
- `dateKey(for:)` / `date(fromKey:)` — `"YYYY-MM-DD"` ⇄ `Date`; `todayKey()`.
- Picker option generators: hours `00..23`, minutes `00..59`, years current ±10.

---

## 6. Calendar tab (`CalendarView`)

- Native graphical `DatePicker` calendar; selecting a day drives the list below.
- For the selected date, a combined list of **events** (for that date) then
  **incomplete tasks due that date** (`DateTimeUtilities.incompleteTasks`).
  - Event row: title, start/end time (formatted); tap to **edit**, swipe to
    **delete**. Empty → "No events or tasks yet".
  - Task row (read-only here, visually distinct): title, `Deadline: …`, notes,
    `Priority: N`.
- **+ Add Event** (toolbar) opens the event editor.

### 6.1 Event editor (`EventEditorSheet`)
Fields: title (default "New Event"), **All Day** toggle (hides the time pickers
when on), start time & end time, notes. Empty title just closes. Saving edits
preserves the event id; adding generates a new id.

---

## 7. Tasks tab (`TaskListView`)

- Header segmented control: **Upcoming (n)** / **Completed (n)**.
  - Upcoming = `completedAt == "na"`, sorted by deadline date ascending.
  - Completed = `completedAt != "na"`, sorted by `completedAt` descending.
- **Floating "+" button** opens the task editor.
- Task card shows: checkbox (toggle completion), title (tap to edit),
  Priority + Performance/100, notes, `Created … | Deadline …`, type tags, a
  subtask preview (first 2, "+N more"), and for completed tasks the completed
  date + performance notes.
- **Completion toggle**:
  - Completing is **blocked if any subtask is incomplete** (alert). Otherwise it
    opens the **Performance Rating** sheet; saving the rating sets
    `performanceRating`(+notes) and marks the task complete (`completedAt` =
    today).
  - Un-completing sets `completedAt = "na"`.
- **Long-press a completed task** → reopen Performance Rating to edit its
  rating/notes (does not change completion).
- **Subtask checkbox** toggles that subtask's `completedAt` (today ↔ `"na"`).
- **Swipe → Delete**.

### 7.1 Task editor (`TaskEditorSheet`)
Fields and defaults: title ("New Task" when blank), Priority slider (0–100,
default 50), Performance slider (0–100, default 50), Create Date (default today),
Deadline date (default today) + optional deadline time, **Recurring** toggle →
Frequency Pattern picker + Frequency Count, Estimated Duration (min), Task Types
(add/remove chips), Subtasks (title+notes, add/remove; each gets `order`), Notes.
Deadline is composed as `T{time}:00` or `T23:59:59`. New tasks start with
`completedAt = "na"`; editing preserves `id`.

### 7.2 Performance Rating (`PerformanceRatingSheet`)
A 0–100 slider (default 50; pre-filled with the task's rating when editing) plus
optional notes. Saving emits `(rating, notes?)`.

---

## 8. Performance tab (`PerformanceView` + `PerformanceAnalytics`)

- Pull-to-refresh reloads tasks.
- **Period selector**: Week / Month / 3 Months / Year / All Time / Custom.
  - Ranges end "now"; start = now − (7d / 1mo / 3mo / 1yr), All Time = epoch,
    Custom = a user-entered `YYYY-MM-DD` start.
  - Filters to **completed** tasks whose `completedAt` falls in range.
- **Stat cards**: tasks completed in period, and average performance (one decimal).
- **Weekly chart** (Swift Charts) — last 5 weeks: average performance of tasks
  completed each week; each point colored by `PerformancePreferencesService`.
- **Monthly chart** — last 5 months, same idea.
- **Insights**: Best Week, Best Month (max-average period), Overall Trend
  (Improving/Declining/Neutral, last vs first weekly average), Total Tasks.
- **Recent Performance**: up to 10 filtered tasks, each with a colored
  performance badge, completed date, rating/100, and notes. Long-press → edit
  rating. Empty period → empty-state message.

---

## 9. Settings tab (`SettingsView`)

- **Settings** root:
  - **Personal Preferences** → Personal Preferences screen (all builds).
  - **Database Management** — **Debug builds only** (compiled out of Release via
    `#if DEBUG`): Database Test (connection check), Database Stats (row counts),
    **Erase All Data** (`reset()`).
- **Personal Preferences** → row to **Performance Cutoffs**.
- **Performance Cutoffs**: numeric inputs for fair/good/veryGood/excellent
  (blank fields fall back to defaults on save), **Save Changes**, **Reset to
  Defaults**. Anything below "Fair" is "Poor".

---

## 10. App bootstrap (`MetroneoApp`)

On launch the app constructs the `CoreDataDatabase` (falling back to
`InMemoryDatabase` if the store fails to load), initializes it, injects the
services into the environment, and loads tasks + events before showing the tabs.

---

## 11. Architecture summary

- **Models** (`Metroneo/Models`) — `Task`, `SubTask`, `Event` value types
  (`Codable`/`Identifiable`).
- **Storage** (`Metroneo/Storage`) — `TaskDatabase` protocol with `CoreDataDatabase`
  and `InMemoryDatabase`.
- **Services** (`Metroneo/Services`) — `TaskService`, `EventService`,
  `PerformancePreferencesService`, and `PerformanceAnalytics` (pure calculations).
- **Utilities** (`Metroneo/Utilities`) — `DateTimeUtilities`, `Color(hex:)`.
- **Views** (`Metroneo/Views` + `Metroneo/App`) — `RootView`, `CalendarView`,
  `TaskListView`, `PerformanceView`, `SettingsView` + sub-screens, and the
  task/event/rating sheets, using the native graphical calendar and Swift Charts.
- **Tests** (`MetroneoTests`) — cover utilities, the in-memory store, services,
  and analytics.
