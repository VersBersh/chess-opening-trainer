# CT-5 Discovered Tasks

## 1. Extract drill screen into smaller files

- **Suggested ID:** CT-5.1
- **Title:** Split drill_screen.dart into separate files
- **Description:** `drill_screen.dart` is ~690 lines combining state classes, controller logic, and widget code. Extract `SessionSummary` data class to `models/session_summary.dart`, session-complete UI to `widgets/session_summary_widget.dart`, and potentially the controller to its own file.
- **Why discovered:** Design review flagged file size as Major issue. Plan deferred splitting as follow-up.

## 2. Extract duration/date formatting utilities

- **Suggested ID:** CT-5.2
- **Title:** Extract and unit-test duration/date formatting helpers
- **Description:** `_formatDuration()` and `_formatNextDue()` are private methods on `DrillScreen`. Extract to a shared utility file and add unit tests for edge cases (zero duration, various day ranges, same-day dates).
- **Why discovered:** These helpers are currently untestable in isolation due to being private widget methods.

## 3. Inject clock abstraction for testability

- **Suggested ID:** CT-5.3
- **Title:** Replace `DateTime.now()` with injectable clock
- **Description:** `DrillController` uses `DateTime.now()` directly for session start time and summary duration. `_formatNextDue` also calls `DateTime.now()`. Inject a clock abstraction (e.g., `DateTime Function()` or `package:clock`) to enable deterministic duration testing.
- **Why discovered:** Design review flagged temporal coupling as Minor issue. Tests can only verify "text exists" rather than exact duration values.
