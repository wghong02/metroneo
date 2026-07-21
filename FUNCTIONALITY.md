# Plannus — Functionality Reference

Plannus is a React Native / Expo task-planning app. This document catalogs every
functionality currently implemented in the codebase, described in
implementation-agnostic terms so it can serve as the specification for ports to
other platforms (e.g. a Swift library).

## 1. Overview

The app is organized around a bottom tab bar with four destinations:

| Tab | Screen | Status |
| --- | --- | --- |
| Calendar | `CalendarScreen` | Fully implemented — the core feature |
| Tasks | `TaskScreen` | Fully implemented — a standalone simple to-do list |
| Performance | `PerformanceScreen` | Placeholder (renders nothing) |
| Settings | `SettingsScreen` | Placeholder (renders nothing) |

There are **two independent data domains** that do not share storage:

1. **Scheduled tasks** — date-keyed tasks with a time and notes (Calendar tab).
2. **Simple to-dos** — a flat list of text strings (Tasks tab).

## 2. Domain models

### 2.1 Task (`models.ts`)

A scheduled task has:

- `id: string` — unique identifier. Generated as `Date.now().toString()`
  (millisecond timestamp) at creation.
- `title: string` — the task description. Required (empty title cancels a save).
- `time: string` — 24-hour `"HH:mm"` clock time (e.g. `"09:00"`, `"14:30"`).
- `notes?: string` — optional free-text notes.

### 2.2 TaskMap (`models.ts`)

`TaskMap = Record<string, Task[]>` — a dictionary keyed by calendar date string
in `"YYYY-MM-DD"` format (the format emitted by the calendar's `dateString`).
Each value is the list of tasks scheduled for that date.

## 3. Scheduled-task persistence (`utils/taskStorage.ts`)

Backed by a key/value store (`AsyncStorage`) under the key `"task"`. Values are
JSON-serialized `TaskMap` objects.

- **`loadTasks(): TaskMap`** — reads and JSON-parses the stored map; returns an
  empty map (`{}`) when nothing is stored.
- **`saveTasks(tasks: TaskMap): void`** — JSON-serializes and writes the entire
  map back to storage.
- **`deleteTask(tasks, date, index): TaskMap`** — removes the task at `index`
  within the given `date`'s list, persists the updated map, and returns it. If
  the date has no entry, the map is returned unchanged.

## 4. Calendar screen (`screens/CalendarScreen.tsx`)

The primary feature. Combines a month calendar with a per-date task list.

### 4.1 Behaviors

- **Load on mount** — hydrates the in-memory `TaskMap` from storage.
- **Date selection** — tapping a day selects it; the selected day is visually
  marked. Until a date is selected, a "Select a date to view tasks" prompt is
  shown instead of the task list.
- **Task list for selected date** — shows the tasks for the selected date, each
  row displaying the formatted time, the title, and a delete control. An empty
  date shows "No tasks yet".
- **Add task** — opens the task modal with defaults (empty title, time
  `"09:00"`, empty notes) and no edit target.
- **Edit task** — tapping a task's title opens the modal pre-filled with that
  task's current values, targeting its index for replacement.
- **Save task** (`handleSaveTask`):
  - If the title is empty, the modal simply closes and nothing is saved.
  - **Edit mode**: replaces the task at the edit index, preserving its `id`.
  - **Add mode**: appends a new task with a freshly generated `id`.
  - After add/edit, the date's task list is **sorted ascending by `time`**
    (lexicographic compare on `"HH:mm"`, which is chronologically correct).
  - The updated map is persisted, then in-memory state is updated and the modal
    closes. A persistence failure is caught and logged.
- **Delete task** — prompts for confirmation ("Delete Task / Are you sure?");
  on confirm, removes the task via the storage `deleteTask` helper.

### 4.2 Time formatting (`formatTime`)

Converts a 24-hour `"HH:mm"` string to a 12-hour display string with meridiem:

- Hour `0` → `12`, hours `> 12` → `hour - 12`, otherwise the hour as-is.
- `AM` when hour `< 12`, else `PM`.
- Minutes are passed through unchanged.
- Examples: `"00:00"` → `"12:00 AM"`, `"09:30"` → `"9:30 AM"`,
  `"13:05"` → `"1:05 PM"`, `"23:30"` → `"11:30 PM"`.

## 5. New/Edit task modal (`components/NewTaskModal.tsx`)

A bottom-sheet form used for both creating and editing scheduled tasks.

### 5.1 Inputs

- **Title / description** — single-line text. The label is configurable
  (`titleLabel`, default `"Task Description"`).
- **Time** — chosen from a dropdown of preset options (see below); shown using
  the same 12-hour `formatTime` display.
- **Notes** — multi-line free text.

### 5.2 Time option generation (`generateTimeOptions`)

Produces the selectable time slots: every 30 minutes across a full day, from
`"00:00"` through `"23:30"` — 48 options total, each formatted `"HH:mm"` with
zero-padding.

### 5.3 Actions

- **Cancel** — dismisses without saving.
- **Save** — emits the current `(title, time, notes)` to the caller.
- On (re)open the form fields reset to the provided initial values.

## 6. Simple to-do list (`screens/TaskScreen.tsx`)

A standalone, flat to-do list independent of the calendar tasks.

- **Storage** — key/value store under the key `"@todos_list"`, holding a
  JSON array of strings.
- **Load on mount** — hydrates the list from storage.
- **Auto-persist** — writes the full list back to storage whenever it changes.
- **Add to-do** — trims the input; ignores empty/whitespace-only input;
  appends the trimmed text and clears the input.
- **Delete to-do** — swipe reveals a delete action; deletion prompts for
  confirmation ("Delete / Are you sure?") and removes the item at its index.

## 7. Navigation (`components/TabNavigator.tsx`)

Bottom tab navigator with the four tabs listed in §1. Each tab has a filled
icon when focused and an outline icon otherwise. Active tint `#007AFF`,
inactive tint gray.

## 8. Placeholder screens

`PerformanceScreen` (`screens/PerformanceScreen.tsx`) and `SettingsScreen`
(`screens/SettingsScreen.tsx`) currently render nothing. Their storage keys
`"performance"` and `"settings"` are declared but unused.

## 9. Behavior summary (for porting)

Pure, platform-independent logic worth preserving in any port:

1. **Task identity** — `id` = creation-time millisecond timestamp as a string.
2. **Time model** — 24-hour `"HH:mm"` strings; sort lexicographically for
   chronological order.
3. **12-hour formatting** — as specified in §4.2.
4. **30-minute slot generation** — 48 slots, `"00:00"`…`"23:30"` (§5.2).
5. **Date-keyed map** — tasks grouped by `"YYYY-MM-DD"` date key.
6. **Save semantics** — empty title is a no-op; edit preserves `id`; add
   generates a new `id`; list re-sorted by time after each mutation.
7. **Delete semantics** — remove by (date, index); missing date is a no-op.
8. **Two separate stores** — scheduled tasks (`"task"`) and simple to-dos
   (`"@todos_list"`).
