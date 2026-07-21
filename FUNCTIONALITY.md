# Plannus — Functionality Reference

Plannus is a task/event planner with performance tracking. This document catalogs
every functionality in the app (as of the `dev` branch, the most complete
version) in implementation-agnostic terms, so it can serve as the specification
for the Swift port under `Sources/Plannus/`.

The original app is React Native / Expo backed by **SQLite** (`plannus.db`).
The Swift port (a native Xcode iOS app under `Plannus/`) re-implements the same
domain model, persistence semantics, services, and analytics with a SwiftUI
front end, persisting through **Core Data** (model `Plannus.xcdatamodeld`).

---

## 1. Overview

Bottom tab bar with four destinations:

| Tab | Purpose |
| --- | --- |
| **Calendar** | Month calendar; per-date list of **events** plus **incomplete tasks** due that day. |
| **Tasks** | Full task manager: create/edit/delete, subtasks, completion with performance rating, Upcoming/Completed toggle. |
| **Performance** | Analytics over completed tasks: period stats, weekly/monthly line charts, insights, recent list. |
| **Settings** | Stack navigator: Personal Preferences → Performance Cutoffs; plus database management (test/stats/content/erase all). |

There are three persisted domains:

1. **Tasks** (+ **SubTasks**) — the core productivity model.
2. **Events** — date-anchored calendar entries.
3. **Preferences** — performance-rating cutoffs (key/value).

---

## 2. Domain models

### 2.1 BaseItem
Common fields: `id?: string`, `title: string`, `notes?: string`.

### 2.2 Task (extends BaseItem)
- `id?` — string; from SQLite this is the integer row id rendered as a string.
- `title` — required; defaults to `"New Task"` when blank.
- `notes?`
- `deadline: string` — ISO-ish. Stored as `"YYYY-MM-DDTHH:mm:ss"`. When the user
  gives no time, it defaults to **`T23:59:59`**; with a time it is `T{HH:mm}:00`.
- `priorityRating: number` — 0–100, default 50.
- `performanceRating: number` — 0–100, default 50.
- `completedAt: string` — `"YYYY-MM-DD"` when complete, or the sentinel **`"na"`**
  when not complete.
- `createDate: string` — `"YYYY-MM-DD"` (local, `en-CA` formatting). Required.
- `frequencyPattern` — one of `daily | weekly | monthly | yearly | custom | none`
  (default `none`).
- `frequencyCount: number` — default 0 (UI default 1).
- `recurring: boolean`.
- `types?: string[]` — freeform tags (stored as a JSON string column).
- `estimatedDuration?: number` (minutes), `actualDuration?: number`.
- `performanceNotes?: string`.
- `subTasks: SubTask[]`.

### 2.3 SubTask (extends BaseItem)
Same rating/deadline/completion fields as Task, plus:
- `parentTaskId?: string`
- `order: number` — display order within the parent.

### 2.4 Event (extends BaseItem)
- `id: string` — required (event-managed).
- `date: string` — `"YYYY-MM-DD"`.
- `allDay?: boolean`
- `startTime?: string`, `endTime?: string` — `"HH:mm"`.
- `EventMap = Record<dateString, Event[]>`.

---

## 3. Persistence (SQLite: `plannus.db`)

`initDatabase` enables `PRAGMA foreign_keys = ON` and creates three tables
(idempotent `CREATE TABLE IF NOT EXISTS`):

- **tasks** — `id INTEGER PK AUTOINCREMENT`, all Task scalar fields; `types` is
  TEXT (JSON), `recurring` is `INTEGER CHECK(0,1)`, `frequencyPattern` is a
  `CHECK`-constrained enum. (Note: `performanceNotes` lives on the model but is
  not a column in the original schema; the Swift port persists it.)
- **subtasks** — `id INTEGER PK`, `parentTaskId` FK → `tasks(id)`
  `ON DELETE CASCADE`, plus base/rating fields and `"order"`.
- **events** — `id TEXT PK`, `date`, `title`, `notes`, `allDay`, `startTime`,
  `endTime`.

Data-layer operations:

- **Tasks** (`taskDatabase.ts`) — `saveTasks(tasks)` runs in an exclusive
  transaction that **deletes all tasks + subtasks then re-inserts** the whole
  list (with defaulting/validation: title→`"New Task"`, ratings→0, etc.); the DB
  assigns task ids; subtasks are inserted per parent. `loadTasks()` reads tasks
  `ORDER BY createDate DESC`, loads each task's subtasks `ORDER BY "order"`,
  parses `types` JSON defensively, coerces ids to strings, and skips rows missing
  `id`/`title`/`createDate`.
- **Events** (`eventDatabase.ts`) — `saveEvents(events)` (bulk delete+insert),
  `saveEvent(event)` (`INSERT OR REPLACE`, single upsert), `deleteEvent(id)`,
  `getEventById(id)`, `getEventsForDate(date)`, `loadEvents()`
  `ORDER BY date ASC, startTime ASC, title ASC`. Requires `title` and `date`.
- **Admin** (`database.ts`) — `getDatabaseStats()` (row counts + connection
  check), `showDatabaseContent()` (human-readable dump of first 5 rows per
  table), `resetDatabase()` (drops all tables in a transaction, then re-inits).

---

## 4. Services (in-memory cache + singletons)

### 4.1 TaskService (singleton)
Caches the task list. Persists by re-saving the whole list (the DB layer does
delete-all + re-insert). Operations:
- `loadTasks()`, `saveTasks(tasks)`
- `addTask(task)` — title defaults to `"New Task"`, notes trimmed; appends.
- `updateTask(updated)` — replaces the task with matching `id`.
- `deleteTask(id)` — removes by id.
- `completeTask(id)` — sets `completedAt` to today (`en-CA` `YYYY-MM-DD`).
- `uncompleteTask(id)` — sets `completedAt` back to `"na"`.
- `updateTaskPriority(id, priority)`.
- `updateTaskPerformance(id, performance, notes?)` and
  `updateCompletedTaskPerformance(id, performance, notes?)` — set
  `performanceRating` (and `performanceNotes`).

### 4.2 EventService (singleton)
Caches events grouped by date (`Record<date, Event[]>`).
- `loadEvents()` — loads all, groups by `date`.
- `addEvent(date, event)` — forces `event.date = date`, upserts, updates cache.
- `updateEvent(date, event)` — upsert + cache replace by id.
- `deleteEvent(date, id)` — delete + cache prune (drops the date key when empty).
- `moveEvent(oldDate, newDate, id)` — re-dates an event and moves it between
  cache buckets.
- `getEventsForDate(date)` — cache-first, else DB.

### 4.3 PerformancePreferencesService (singleton, key/value)
Stores `PerformanceCutoffs { fair, good, veryGood, excellent }` under
`@performance_cutoffs`.
- **Defaults: `fair 60, good 75, veryGood 80, excellent 90`.**
  (The Cutoffs *screen* seeds its inputs with `25/50/75/100`, but the service
  default is `60/75/80/90`.)
- `getCutoffs()`, `setCutoffs(c)`, `resetToDefaults()`.
- `getPerformanceText(rating, cutoffs)` → `Excellent | Very Good | Good | Fair |
  Poor` (Poor is anything below `fair`).
- `getPerformanceColor(rating, cutoffs)` → hex:
  Excellent `#2E7D32`, Very Good `#4CAF50`, Good `#2196F3`, Fair `#FF9800`,
  Poor `#F44336`.

---

## 5. Utility functions

- **`formatTime("HH:mm")`** → 12-hour `"h:mm AM/PM"` (hour 0→12, >12 subtract 12).
- **`formatDeadline("YYYY-MM-DD[THH:mm:ss]")`** → localized date, and if a time
  part is present, `"<date> at <formatTime(HH:mm)>"`.
- **`getIncompleteTasksForDate(tasks, targetDate)`** → tasks whose `completedAt`
  is `"na"` and whose deadline **date part** equals `targetDate` (exact day).
- Time picker options: hours `00..23`, minutes `00..59` (per-minute); event/task
  time strings are `"HH:mm"`. Date picker range: current year ±10.

---

## 6. Calendar tab

- Month calendar; tap a day to select it (selected day highlighted). Before any
  selection: prompt "Select a date to view events and tasks".
- For the selected date, shows a combined list of **events** (for that date) then
  **incomplete tasks due that date** (`getIncompleteTasksForDate`).
  - Event row: title, start/end time (formatted), tap title to **edit**, ✕ to
    **delete** (confirm alert). Empty → "No events or tasks yet".
  - Task row (read-only here, visually distinct): title, `Deadline: …`, notes,
    `Priority: N`.
- **+ Add Event** opens the event modal. Data reloads when the screen refocuses.

### 6.1 New/Edit Event modal
Fields: title (default "New Event"), **All Day** toggle (clears times when on;
restores defaults `08:00`/`09:00` when off), start time & end time (wheel
pickers, shown only when not all-day), notes. Empty title → just closes. Save
emits `(title, startTime, endTime, notes, allDay)`; edit preserves the event id,
add generates `event-{timestamp}-{rand}`.

---

## 7. Tasks tab

- Header toggle: **Upcoming (n)** / **Completed (n)**.
  - Upcoming = `completedAt === "na"`, sorted by deadline date ascending.
  - Completed = `completedAt !== "na"`, sorted by `completedAt` descending.
- **FAB (+)** opens the New Task modal.
- Task card shows: checkbox (toggle completion), title (tap to edit),
  Priority + Performance/100, notes, `Created … | Deadline …`, estimated
  duration, type tags, a subtask preview (first 2, "+N more"), and for completed
  tasks the completed date + performance notes.
- **Completion toggle**:
  - Completing is **blocked if any subtask is incomplete** (alert). Otherwise it
    opens the **Performance Rating** modal; saving the rating sets
    `performanceRating`(+notes) and marks the task complete (`completedAt` =
    today).
  - Un-completing sets `completedAt = "na"`.
- **Long-press a completed task** → reopen Performance Rating modal to edit its
  rating/notes (does not change completion).
- **Subtask checkbox** toggles that subtask's `completedAt` (today ↔ `"na"`).
- **Swipe → Delete** (confirm alert).

### 7.1 New Task modal
Fields and defaults: title ("New Task" when blank), Priority slider (0–100,
default 50), Performance slider (0–100, default 50), Create Date (wheel, default
today), Deadline date (wheel, default today) + optional deadline time,
**Recurring** toggle → reveals Frequency Pattern buttons + Frequency Count,
Estimated Duration (min), Task Types (add/remove tag chips), Subtasks
(title+notes, add/remove; each subtask gets `order`), Notes. Deadline is composed
as `T{time}:00` or `T23:59:59`. New tasks are created with `completedAt = "na"`.

### 7.2 Edit Task modal
Same fields, pre-populated from the task; preserves `id`.

### 7.3 Performance Rating modal
A 0–100 slider (default 50; pre-filled with the task's rating when editing) plus
optional notes. Save emits `(taskId, rating, notes?)`.

---

## 8. Performance tab

- Pull-to-refresh reloads tasks + cutoffs.
- **Period selector**: Week / Month / 3 Months / Year / All Time / Custom.
  - Ranges end "now"; start = now − (7d / 1mo / 3mo / 1yr), All Time = epoch,
    Custom = a user-entered `YYYY-MM-DD` (validated) start.
  - Filters to **completed** tasks whose `completedAt` falls in range.
- **Stat cards**: tasks completed in period, and average performance
  (`sum/ count`, one decimal).
- **Weekly chart** — last 5 weeks: for each week window, average performance of
  tasks completed that week; label = that week's Monday (`MMM d`); trend up/down/
  stable vs previous.
- **Monthly chart** — last 5 months: average per month, label `MMM`.
- **Insights**: Best Week, Best Month (max-average period), Overall Trend
  (Improving/Declining/Neutral comparing last vs first weekly average), Total
  Tasks (all completed).
- **Recent Performance**: up to 10 filtered tasks, each with a colored
  performance badge (`getPerformanceColor`/`Text`), completed date, rating/100,
  and notes. Long-press → edit rating. Empty period → empty-state message.

---

## 9. Settings tab (stack navigator)

- **Settings** root:
  - **Personal Preferences** → Personal Preferences screen.
  - **Database Management**: Database Test (connection check), Database Stats
    (row counts), Database Content (dump), **Erase All Data** (confirm →
    `resetDatabase` → reload app).
- **Personal Preferences** screen → row to **Performance Cutoffs**.
- **Performance Cutoffs** screen: numeric inputs for fair/good/veryGood/excellent
  (blank fields fall back to defaults on save), **Save Changes**, **Reset to
  Defaults**. Description notes anything below "Fair" is "Poor".

---

## 10. App bootstrap
On launch the app initializes the database (creates tables if missing) before
rendering the tab navigator.

---

## 11. Port notes (Swift)
The Swift implementation (`Plannus/`, an Xcode app target) mirrors the above:
- Domain models are `Codable`/`Identifiable` structs.
- A `TaskDatabase` protocol abstracts persistence; a **Core Data**–backed
  implementation (`CoreDataDatabase`, model `Plannus.xcdatamodeld` with entities
  `CDTask`, `CDSubTask`, `CDEvent`) is the production default, and an
  `InMemoryDatabase` backs tests/previews. Delete-all-then-insert save semantics
  are preserved.
- `TaskService`, `EventService`, and `PerformancePreferencesService` are
  `ObservableObject` singletons matching the operations in §4.
- `PerformanceAnalytics` implements the period filtering, averages, and
  weekly/monthly series from §8.
- SwiftUI views (`RootView`, `CalendarView`, `TaskListView`, `PerformanceView`,
  `SettingsView` + sub-screens, and the task/event/rating sheets) implement the
  UI behaviors in §6–§9, using the native graphical calendar and pickers.
