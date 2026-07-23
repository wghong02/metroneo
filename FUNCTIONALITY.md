# Metroneo — Functionality Reference

Metroneo is a native iOS task/event planner with performance tracking, written in
Swift + SwiftUI and persisted with **SwiftData**. This document catalogs every
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

The domain types (`Task`, `SubTask`, `Event`) are Swift **value types** used
throughout the app. The store maps them to/from SwiftData `@Model` classes (§3).

### 2.1 Common fields
Every task/subtask carries `id: String?`, `title: String`, `notes: String?`.
Events use a required `id: String`.

### 2.2 Task
- `id?` — a stable UUID string assigned once when the task is first added; it is
  **never reassigned** across edits or saves.
- `title` — required; defaults to `"New Task"` when blank.
- `notes?`
- `deadline: Date` — a full instant. A time of **`23:59:59`** marks an end-of-day
  deadline with *no explicit time*; any other time is the user's chosen time.
- `priorityRating: Int` — 0–100, default 50.
- `performanceRating: Int` — 0–100, default 50.
- `completedAt: Date?` — the completion instant, or **`nil`** when not complete
  (`isCompleted == (completedAt != nil)`).
- `createDate: Date` — required.
- `frequencyPattern` — one of `daily | weekly | monthly | yearly | custom | none`
  (default `none`).
- `frequencyCount: Int` — default 0 (editor default 1).
- `recurring: Bool`.
- `types: [String]?` — freeform tags.
- `estimatedDuration: Int?` (minutes), `actualDuration: Int?`.
- `performanceNotes: String?`.
- `subTasks: [SubTask]`.

### 2.3 SubTask
Same rating/deadline/completion fields as Task (`deadline: Date`,
`completedAt: Date?`), plus:
- `parentTaskId: String?`
- `order: Int` — display order within the parent.

### 2.4 Event
- `id: String` — required.
- `date: Date` — the event's day, normalized to local start-of-day.
- `allDay: Bool`
- `startTime: Date?`, `endTime: Date?` — times of day, anchored to the event's day.
- `EventMap = [Date: [Event]]` — events grouped by local start-of-day.

---

## 3. Persistence

Persistence is **SwiftData**. `SwiftDataDatabase` is the sole store; it maps the
domain value types to/from three `@Model` classes — `StoredTask`, `StoredSubTask`,
`StoredEvent` — with a cascade-delete relationship from a task to its subtasks. An
`inMemory` initializer backs the tests. There is no Objective-C and no
`.xcdatamodeld`: `Int`, `Date`, `[String]`, and the `FrequencyPattern` enum all
persist natively.

Operations:

- **Tasks** — `saveTasks(tasks)` replaces the entire task + subtask set (delete-all
  then insert), **preserving each incoming id** (minting a UUID only when one is
  missing) so nothing is reshuffled. Blank titles fall back to defaults and subtask
  `order` is set from position. `loadTasks()` returns tasks ordered by `createDate`
  descending, each with its subtasks ordered by `order`.
- **Events** — `saveEvent(event)` upserts a single event (by unique `eventID`);
  `deleteEvent(id)` and `loadEvents()` (ordered by date, then start time, then
  title). `title` is required.
- **Admin** — `reset()` (clears all data) and `stats()` (row counts + state).
  Constructing the store `throws MetroneoError.database` if it fails to open; the
  app treats that as fatal (§10).

---

## 4. Services

`TaskService`, `EventService`, and `PerformancePreferencesService` are
`ObservableObject`s injected through the SwiftUI environment; they cache state and
delegate persistence to `SwiftDataDatabase` (or `UserDefaults` for preferences).

### 4.1 TaskService
Holds an **in-memory working copy** of the task list. Mutations edit that copy and
set `hasUnsavedChanges`; **nothing is written to the store until `save()`**. Because
ids are stable, a captured id stays valid across any number of edits and saves.
- `loadTasks()` — loads from the store and clears the dirty flag.
- `save()` — persists the working copy, then reloads it.
- `discardChanges()` — reloads from the store, dropping unsaved edits.
- `addTask(task)` — assigns a stable id, defaults a blank title, appends.
- `updateTask(updated)` — replaces the task with matching `id`.
- `deleteTask(id)` — removes by id.
- `completeTask(id)` — sets `completedAt` to the current instant.
- `uncompleteTask(id)` — clears `completedAt` (`nil`).
- `updateTaskPerformance(id, performance, notes?)` — sets `performanceRating`
  (and `performanceNotes`).
- `toggleSubTask(taskId, subTaskId)` — flips a subtask's `completedAt` (now ↔ nil).

### 4.2 EventService
Caches events grouped by local start-of-day (`[Date: [Event]]`). Unlike tasks,
event edits **persist immediately**.
- `loadEvents()` — loads all, groups by start-of-day.
- `addEvent(date, event)` / `updateEvent(date, event)` — normalize the event to that
  day and re-anchor its start/end times to it, upsert, update cache.
- `deleteEvent(date, id)` — delete + cache prune (drops the day key when empty).
- `events(on: date)` — cached lookup by start-of-day.

### 4.3 PerformancePreferencesService
Stores `PerformanceCutoffs { fair, good, veryGood, excellent }` in `UserDefaults`
under `@performance_cutoffs`.
- **Defaults: `fair 60, good 75, veryGood 80, excellent 90`.**
- `cutoffs`, `setCutoffs(c)`, `resetToDefaults()`.
- `text(for:)` → `Excellent | Very Good | Good | Fair | Poor`
  (Poor is anything below `fair`).
- The matching fill `Color` for a rating/level is defined in `Palette.swift`
  (`color(for:)` / `PerformanceLevel.color`) — green → blue → orange → red.
  Surfaces use adaptive system colors, so the UI is correct in dark mode.

---

## 5. Utility functions (`DateTimeUtilities`)

- **`startOfDay(date)`** / **`endOfDay(day)`** — local day boundaries; `endOfDay`
  returns `23:59:59`, the "no explicit time" deadline sentinel.
- **`combine(day:time:)`** — merges a day's calendar date with a time-of-day.
- **`hasExplicitTime(deadline)`** — false when the deadline is the `23:59:59`
  end-of-day sentinel.
- **`shortDate(date)`** — localized short date.
- **`formatDeadline(deadline: Date)`** — localized date, plus `"<date> at <time>"`
  when the deadline carries an explicit (non-end-of-day) time.
- **`incompleteTasks(_:forDate:)`** — tasks with `completedAt == nil` whose deadline
  falls on the same day as the target date.

Event start/end times are displayed with SwiftUI's `Date.formatted`; there is no
bespoke time-string formatter.

---

## 6. Calendar tab (`CalendarView`)

- Native graphical `DatePicker` calendar; selecting a day drives the list below.
- For the selected date, a combined list of **events** (for that date) then
  **incomplete tasks due that date** (`DateTimeUtilities.incompleteTasks`).
  - Event row: title, start/end time (via `Date.formatted`); tap to **edit**, swipe
    to **delete**. Empty → "No events or tasks yet".
  - Task row (read-only here, visually distinct): title, `Deadline: …`, notes,
    `Priority: N`.
- **+ Add Event** (toolbar) opens the event editor.

### 6.1 Event editor (`EventEditorSheet`)
Fields: title (default "New Event"), **All Day** toggle (hides the time pickers
when on), start time & end time (hour-and-minute `DatePicker`s bound to `Date`),
notes. Empty title just closes. Saving edits preserves the event id; adding
generates a new id. The service re-anchors the chosen times to the event's day.

---

## 7. Tasks tab (`TaskListView`)

- Header segmented control: **Upcoming (n)** / **Completed (n)**.
  - Upcoming = not completed, sorted by `deadline` ascending.
  - Completed = completed, sorted by `completedAt` descending.
- **Save** (checkmark) toolbar button — persists the working copy; enabled only when
  there are unsaved changes. All the actions below stage edits **in memory** until
  Save is tapped.
- **Floating "+" button** opens the task editor.
- Task card shows: checkbox (toggle completion), title (tap to edit),
  Priority + Performance/100, notes, `Created … | Deadline …`, type tags, a
  subtask preview (first 2, "+N more"), and for completed tasks the completed
  date + performance notes.
- **Completion toggle**:
  - Completing is **blocked if any subtask is incomplete** (alert). Otherwise it
    opens the **Performance Rating** sheet; saving the rating sets
    `performanceRating`(+notes) and marks the task complete (`completedAt` = now).
  - Un-completing clears `completedAt`.
- **Touch and hold a task** → context menu with **Edit**, and (for completed
  tasks) **Edit Rating** which reopens Performance Rating to edit its rating/notes
  without changing completion.
- **Subtask checkbox** toggles that subtask's `completedAt` (now ↔ nil).
- **Swipe → Delete**.

### 7.1 Task editor (`TaskEditorSheet`)
Fields and defaults: title ("New Task" when blank), Priority slider (0–100,
default 50), Performance slider (0–100, default 50), Create Date (default today),
Deadline date (default today) + optional deadline time, **Recurring** toggle →
Frequency Pattern picker + Frequency Count, Estimated Duration (min), Task Types
(add/remove chips), Subtasks (title+notes, add/remove; each gets `order`), Notes.
The deadline is `endOfDay(day)` when no time is set, or `combine(day, time)` when a
time is. New tasks start not-complete (`completedAt = nil`); editing preserves `id`.

### 7.2 Performance Rating (`PerformanceRatingSheet`)
A 0–100 slider (default 50; pre-filled with the task's rating when editing) plus
optional notes. Saving emits `(rating, notes?)`.

---

## 8. Performance tab (`PerformanceView` + `PerformanceAnalytics`)

- **Period selector** (default **Month**): Week / Month / 3 Months / Year /
  All Time / Custom.
  - Ranges end "now"; start = now − (7d / 1mo / 3mo / 1yr), All Time = epoch,
    Custom = a start date chosen with a `DatePicker` (bounded to today or earlier).
  - Selects the **completed** tasks whose `completedAt` falls in range. This one
    filtered set scopes the **whole page** — stats, charts, insights, and the
    recent list all derive from it, so the selector drives everything.
  Rating edits made here mark the shared task state unsaved; they're persisted
  from the Tasks tab's Save button (this analytics view has no Save control).
- The page is split by a divider into a **"This Period"** section (selector +
  stats) and a **"Trends"** section (charts + insights), with a **"Recent
  Performance"** section below.
- **Stat cards**: tasks completed in period, and average performance (one decimal).
- **Trend chart** (Swift Charts) — a single line/point chart whose bucket
  granularity **follows the window span**, escalating to stay within 12 buckets:
  daily (≤12 days) → weekly (≤~2 months) → monthly (≤12 mo) → quarterly (≤36 mo)
  → half-year (≤72 mo) → yearly (capped at 12 buckets ≈ last 12 years). Month-based
  buckets are calendar-aligned (e.g. `Q3 '26`, `H2 '26`, `2026`); the most recent
  bucket ends today. Each point averages the `performanceRating` of the tasks
  completed in its bucket, colored by `PerformancePreferencesService`. Faint dashed
  **reference lines** mark the cutoff thresholds (labeled near their right end with
  the level name they open, colored to match). **Tap/drag** a point to inspect its
  period, average, and task count. Only the x/y axis lines show (no interior grid);
  numeric labels sit on the left, and x labels rotate vertical past 8 buckets.
- **Insights**: Best Period (max-average bucket), Overall Trend
  (Improving/Declining/Neutral, last vs first bucket), and Best Rating (highest
  rating in the period) — all over the selected period.
- **Recent Performance**: up to 10 filtered tasks, each with a colored
  performance badge, completed date, rating/100, and notes. Touch and hold a row
  → **Edit Rating** context action. Empty period → empty-state message.

---

## 9. Settings tab (`SettingsView`)

- **Settings** root:
  - **Personal Preferences** → Personal Preferences screen (all builds).
  - **Database Management** — **Debug builds only** (compiled out of Release via
    `#if DEBUG`): Database Test (connection check), Database Stats (row counts),
    **Erase All Data** (`reset()`).
- **Personal Preferences** → row to **Performance Cutoffs**.
- **Performance Cutoffs**: integer inputs for fair/good/veryGood/excellent
  (`TextField(value:format:)`, number-pad), **Save Changes**, **Reset to
  Defaults**. Anything below "Fair" is "Poor".

---

## 10. App bootstrap (`MetroneoApp`)

On launch the app constructs `SwiftDataDatabase` — a failure to open the store is
**fatal** (no fallback) — injects the services into the environment, and loads
tasks + events before showing the tabs.

---

## 11. Architecture summary

- **Models** (`Metroneo/Models`) — `Task`, `SubTask`, `Event` value types
  (`Codable`/`Identifiable`).
- **Storage** (`Metroneo/Storage`) — `SwiftDataDatabase` (single engine) plus the
  `@Model` types in `StoredModels`. No persistence protocol.
- **Services** (`Metroneo/Services`) — `TaskService`, `EventService`,
  `PerformancePreferencesService`, and `PerformanceAnalytics` (pure calculations).
- **Utilities** (`Metroneo/Utilities`) — `DateTimeUtilities` and `Palette`
  (performance colors + the shared `cardStyle()` surface).
- **Views** (`Metroneo/Views` + `Metroneo/App`) — `RootView`, `CalendarView`,
  `TaskListView`, `PerformanceView`, `SettingsView` + sub-screens, and the
  task/event/rating sheets, using the native graphical calendar and Swift Charts.
- **Tests** (`MetroneoTests`) — cover utilities, the SwiftData store, services,
  and analytics.
