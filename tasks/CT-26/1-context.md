# CT-26 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/drill_screen.dart` | Contains `_formatDuration()` (line 1112) and `_formatNextDue()` (line 1144) as private methods on `DrillScreen`. These are the extraction targets. |
| `src/lib/services/chess_utils.dart` | Existing shared utility file under `services/`. Demonstrates the pattern: a top-level function file with a matching test file. |
| `src/test/services/chess_utils_test.dart` | Unit tests for `chess_utils.dart`. Shows the project's test conventions: `flutter_test`, `group()` + `test()`, import via `package:chess_trainer/...`. |
| `src/test/screens/drill_screen_test.dart` | Existing widget-level tests for `DrillScreen`. After extraction, the formatting logic will no longer need widget tests -- unit tests in a new file will cover it. |
| `src/lib/services/sm2_scheduler.dart` | Uses `{DateTime? today}` optional parameter to make `DateTime.now()` injectable for testing. This is the codebase's established pattern for clock-dependent code. |
| `src/pubspec.yaml` | Package name is `chess_trainer`. Imports follow `package:chess_trainer/<path>`. |

## Architecture

### Subsystem: Drill Session Summary Display

After a drill session ends, `DrillScreen._buildSessionComplete()` renders a summary card showing:

- Number of cards reviewed / skipped
- Session duration (formatted via `_formatDuration`)
- Quality breakdown (perfect / hesitation / struggled / failed)
- Next review date (formatted via `_formatNextDue`)

### How the formatting methods work

**`_formatDuration(Duration)`** -- Pure function. Converts a `Duration` into a human-readable string: `"Xm Ys"` when minutes > 0, or just `"Ys"` otherwise. No external dependencies.

**`_formatNextDue(DateTime)`** -- Impure function (calls `DateTime.now()`). Computes the calendar-day difference between "now" and the due date, returning:
- `"Today"` if difference <= 0
- `"Tomorrow"` if difference == 1
- `"In N days"` if 2..30
- `"YYYY-MM-DD"` if > 30

### Key Constraints

1. **No `utils/` directory exists.** The existing convention is to place shared logic under `src/lib/services/`. A new file there is the natural fit.
2. **`DateTime.now()` testability.** The codebase already uses an optional `DateTime? today` parameter pattern (see `sm2_scheduler.dart`, `local_review_repository.dart`). The extracted `formatNextDue` should follow the same pattern.
3. **Test mirror structure.** Tests live under `src/test/<subfolder>/` matching `src/lib/<subfolder>/`. A new test file at `src/test/services/` is expected.
4. **Package imports.** All imports use `package:chess_trainer/...` style, not relative paths.
