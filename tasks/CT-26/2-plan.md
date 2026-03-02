# CT-26 Implementation Plan

## Goal

Extract `_formatDuration()` and `_formatNextDue()` from `DrillScreen` into a shared utility file with comprehensive unit tests, making the formatting logic independently testable.

## Steps

### 1. Create the utility file `src/lib/services/format_utils.dart`

Create a new file with two top-level functions:

```dart
/// Formats a Duration as a human-readable string.
/// Returns "Xm Ys" when minutes > 0, or "Ys" otherwise.
String formatDuration(Duration duration) { ... }

/// Formats a next-due DateTime relative to today.
/// Returns "Today", "Tomorrow", "In N days", or "YYYY-MM-DD".
/// [today] defaults to DateTime.now() but can be injected for testing.
String formatNextDue(DateTime nextDue, {DateTime? today}) { ... }
```

- Copy the body of `_formatDuration` from `drill_screen.dart` lines 1112-1119 into the `formatDuration` top-level function.
- Copy the body of `_formatNextDue` from `drill_screen.dart` lines 1144-1159 into the `formatNextDue` top-level function.
- Do **not** copy `_buildBreakdownRow` (lines 1121-1142) -- it is a UI widget method that sits between the two formatters in the source and must remain in `DrillScreen`.
- Drop the leading underscore to make both functions public.
- Replace the hard-coded `DateTime.now()` in `formatNextDue` with an optional `{DateTime? today}` parameter (defaulting to `DateTime.now()`), following the naming convention established in `sm2_scheduler.dart` and `drill_engine.dart`.

### 2. Update `src/lib/screens/drill_screen.dart` to use the extracted helpers

- Add import: `import '../services/format_utils.dart';`
- Replace the call at line 1071 (`_formatDuration(summary.sessionDuration)`) with `formatDuration(summary.sessionDuration)`.
- Replace the call at line 1095 (`_formatNextDue(summary.earliestNextDue!)`) with `formatNextDue(summary.earliestNextDue!)`.
- Delete the `_formatDuration` method (lines 1112-1119).
- Delete the `_formatNextDue` method (lines 1144-1159).
- Leave `_buildBreakdownRow` (lines 1121-1142) in place -- it is a UI helper that belongs in the screen.

### 3. Create the test file `src/test/services/format_utils_test.dart`

Add unit tests covering the following edge cases:

**`formatDuration` group:**
- Zero duration (`Duration.zero`) -- expect `"0s"`
- Seconds only (e.g., 45 seconds) -- expect `"45s"`
- Exactly one minute (60 seconds) -- expect `"1m 0s"`
- Minutes and seconds (e.g., 3m 7s) -- expect `"3m 7s"`
- Large duration (e.g., 125 minutes 30s) -- expect `"125m 30s"`

**`formatNextDue` group:**
- Same day (due date is today) -- expect `"Today"`
- Past date (due date is yesterday) -- expect `"Today"` (difference <= 0)
- Tomorrow (difference == 1) -- expect `"Tomorrow"`
- Two days out (difference == 2) -- expect `"In 2 days"`
- Boundary: 30 days out -- expect `"In 30 days"`
- Boundary: 31 days out -- expect formatted date `"YYYY-MM-DD"`
- Cross-day edge: now is late evening, due date is early next morning (same calendar day difference logic) -- expect `"Tomorrow"`

All tests should inject `today` explicitly to avoid flaky clock-dependent behavior.

### 4. Run tests and verify

All `flutter test` commands must be run from the `src/` directory (where `pubspec.yaml` lives):

```bash
cd src
flutter test test/services/format_utils_test.dart
flutter test test/screens/drill_screen_test.dart
flutter test
```

- Run `flutter test test/services/format_utils_test.dart` to verify the new tests pass.
- Run `flutter test test/screens/drill_screen_test.dart` to verify the existing drill screen tests still pass.
- Run `flutter test` to verify no regressions across the full suite.

## Risks / Open Questions

1. **No risk of breaking callers.** The two methods are private (`_`-prefixed) and only used within `DrillScreen` itself. There are no other callers in the codebase.

2. **`DateTime.now()` in tests.** The `formatNextDue` function currently hard-codes `DateTime.now()`. The plan injects it via an optional parameter. This is a minor signature change but has zero impact since the function is currently private and uncallable from outside `DrillScreen`. The public API will default to `DateTime.now()` so the call site in `DrillScreen` does not need to pass `today`.

3. **File placement: `services/` vs a new `utils/` directory.** The codebase has no `utils/` directory. Placing the file under `services/` follows the existing pattern (`chess_utils.dart` is already there). If a `utils/` directory is preferred for non-service logic, that is an alternative, but it would introduce a new directory convention.

4. **Clock parameter naming: `today` chosen over `now`.** The review flagged that the original plan used `{DateTime? now}` while existing codebase conventions use `{DateTime? today}` (`sm2_scheduler.dart`, `drill_engine.dart`) and `{DateTime? asOf}` (`local_review_repository.dart`). The revised plan adopts `today` because (a) it matches the majority convention in the codebase, and (b) `formatNextDue` truncates both inputs to calendar days, making `today` semantically accurate.
