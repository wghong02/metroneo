# Metroneo

Metroneo is a native iOS task and event planner with built-in performance
tracking, built in **Swift + SwiftUI** and backed by **Core Data**.

Plan your day on a calendar, manage tasks with subtasks and priorities, rate how
well you performed as you complete them, and review your trends over time with
charts.

## Features

- **Calendar** — a native month calendar; for any day, see its events alongside
  the incomplete tasks due that day.
- **Tasks** — create/edit/delete tasks with notes, priority, deadline (date +
  optional time), recurrence, estimated duration, freeform type tags, and
  subtasks. Toggle between **Upcoming** and **Completed**. Completing a task
  requires its subtasks to be done and prompts for a performance rating.
- **Events** — date-anchored entries with optional start/end times or an
  all-day flag.
- **Performance** — analytics over completed tasks: pick a time period, see the
  count and average score, weekly/monthly line charts (Swift Charts), insight
  highlights, and a recent-tasks list with color-coded scores.
- **Settings** — customize the performance-rating cutoffs (Poor → Excellent).
  A developer-only Database Management panel is available in Debug builds.

See [`FUNCTIONALITY.md`](FUNCTIONALITY.md) for a complete, section-by-section
specification of every behavior.

## Requirements

- Xcode 16 or later
- iOS 16.0+ deployment target

## Getting started

```sh
open Metroneo.xcodeproj
```

Select the **Metroneo** scheme and an iOS Simulator (or a device), then Run
(⌘R). No third-party dependencies or package resolution are required — the app
uses only Apple frameworks (SwiftUI, Core Data, Charts).

### Running the tests

Product ▸ Test (⌘U), or:

```sh
xcodebuild test -scheme Metroneo -destination 'platform=iOS Simulator,name=iPhone 15'
```

The `MetroneoTests` target covers the date/time utilities, the in-memory store,
the services, and the performance analytics.

## Architecture

The app separates a pure, testable domain layer from the SwiftUI presentation
layer. Persistence sits behind a protocol so tests and previews swap in an
in-memory store.

```
Metroneo/
├── App/          MetroneoApp (entry point), RootView (tab bar)
├── Models/       Task, SubTask, Event value types
├── Storage/      TaskDatabase protocol; CoreDataDatabase + InMemoryDatabase
├── Services/     TaskService, EventService, PerformancePreferencesService,
│                 PerformanceAnalytics
├── Utilities/    DateTimeUtilities, Color(hex:)
├── Views/        CalendarView, TaskListView, PerformanceView, SettingsView,
│                 and the task/event/rating sheets
└── Resources/    Metroneo.xcdatamodeld (Core Data model)

MetroneoTests/     Unit tests for utilities, storage, services, analytics
```

- **Models** are `Codable`/`Identifiable` structs with no framework dependencies.
- **`TaskDatabase`** abstracts persistence. `CoreDataDatabase` is the production
  store (model entities `CDTask`, `CDSubTask`, `CDEvent`); `InMemoryDatabase`
  backs tests and previews. Saving tasks replaces the whole task + subtask set.
- **Services** are `ObservableObject`s injected via the SwiftUI environment; they
  cache state and delegate persistence to a `TaskDatabase` (preferences use
  `UserDefaults`).
- **`PerformanceAnalytics`** holds the period filtering and weekly/monthly
  aggregation as pure functions.

## Data model at a glance

| Type | Key fields |
| --- | --- |
| `Task` | title, notes, deadline, priority/performance ratings (0–100), completedAt, createDate, recurrence, types, durations, subtasks |
| `SubTask` | title, ratings, deadline, completion, order within its parent |
| `Event` | id, date, title, notes, allDay, start/end time |

Times are 24-hour `"HH:mm"` strings; dates are `"YYYY-MM-DD"` keys. A task's
`completedAt` is `"na"` until it is completed.

## Project history

Metroneo began as a React Native / Expo app. That original implementation is
preserved on the **`old-expo-react-native`** branch; `master` is the native
Swift + SwiftUI rewrite.
