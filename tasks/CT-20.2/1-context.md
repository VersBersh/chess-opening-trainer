# CT-20.2 Context

## Relevant Files

- **`src/lib/screens/drill_screen.dart`** — Contains `_formatNextDue` (lines 1144-1157) with the boundary bug. Also contains `SessionSummary` data class and the summary UI that calls `_formatNextDue`.
- **`src/test/screens/drill_screen_test.dart`** — Widget tests for `DrillScreen`. Line 811 comment references "Tomorrow" for quality 5 / interval 1 day. Assertion uses `textContaining('Next review:')` (not the specific label).
- **`src/lib/services/sm2_scheduler.dart`** — SM-2 scheduler computing `nextReviewDate = now + Duration(days: interval)` with minimum interval of 1 day.

## Architecture

The drill summary subsystem:

1. **SM-2 scheduling** (`sm2_scheduler.dart`): On card completion, computes `nextReviewDate = DateTime.now() + interval_days`. Minimum interval is 1 day.
2. **Controller** (`drill_screen.dart`, `DrillController`): Tracks earliest `nextReviewDate` across completed cards via `_earliestNextDue`, passed into `SessionSummary`.
3. **UI formatting** (`drill_screen.dart`, `_formatNextDue`): Truncates both `DateTime.now()` and `nextDue` to date-only, computes day difference, then maps to a label string.
4. **The bug**: `difference <= 1` returns "Tomorrow", but this catches `difference == 0` (same-day) and negative values (overdue), both of which should not say "Tomorrow".
