# CT-5 Implementation Plan

## Goal

Extend the drill session completion flow to collect per-card statistics (mistake breakdown, next review dates) and session duration, then display them in an enhanced post-drill summary UI.

## Steps

### 1. Define a `SessionSummary` data class

**File:** `src/lib/screens/drill_screen.dart` (modify)

Add near the other state classes:

```dart
class SessionSummary {
  final int totalCards;
  final int completedCards;
  final int skippedCards;
  final int perfectCount;     // quality 5 (0 mistakes)
  final int hesitationCount;  // quality 4 (1 mistake)
  final int struggledCount;   // quality 2 (2 mistakes)
  final int failedCount;      // quality 1 (3+ mistakes)
  final Duration sessionDuration;
  final DateTime? earliestNextDue;

  const SessionSummary({
    required this.totalCards,
    required this.completedCards,
    required this.skippedCards,
    required this.perfectCount,
    required this.hesitationCount,
    required this.struggledCount,
    required this.failedCount,
    required this.sessionDuration,
    this.earliestNextDue,
  });
}
```

No dependencies.

### 2. Update `DrillSessionComplete` to carry a `SessionSummary`

**File:** `src/lib/screens/drill_screen.dart` (modify)

Replace individual fields with `SessionSummary`:

```dart
class DrillSessionComplete extends DrillScreenState {
  final SessionSummary summary;
  const DrillSessionComplete({required this.summary});
}
```

Depends on: Step 1.

### 3. Add session tracking fields to `DrillController` and extract `_buildSummary()` helper

**File:** `src/lib/screens/drill_screen.dart` (modify)

Add fields to `DrillController`:
- `DateTime _sessionStartTime = DateTime.now();`
- `int _perfectCount = 0;`
- `int _hesitationCount = 0;`
- `int _struggledCount = 0;`
- `int _failedCount = 0;`
- `DateTime? _earliestNextDue;`

Initialize `_sessionStartTime` immediately before `_engine.startCard()` in `build()` (after repository I/O and tree construction, so duration reflects active drill time, not setup latency). Reset quality counters to 0 alongside existing `_completedCards`/`_skippedCards` resets.

Extract a `_buildSummary()` helper to avoid duplicating `SessionSummary` construction:

```dart
SessionSummary _buildSummary() => SessionSummary(
  totalCards: _engine.totalCards,
  completedCards: _completedCards,
  skippedCards: _skippedCards,
  perfectCount: _perfectCount,
  hesitationCount: _hesitationCount,
  struggledCount: _struggledCount,
  failedCount: _failedCount,
  sessionDuration: DateTime.now().difference(_sessionStartTime),
  earliestNextDue: _earliestNextDue,
);
```

Depends on: Steps 1, 2.

### 4. Accumulate per-card statistics in `_handleLineComplete()` and update `skipCard()`/`build()`

**File:** `src/lib/screens/drill_screen.dart` (modify)

In `_handleLineComplete()`, the existing code already guards `completeCard()` with `if (result != null)`. Inside that guard block, after `saveReview`, accumulate statistics:

```dart
final result = _engine.completeCard();
if (result != null) {
  await _reviewRepo.saveReview(result.updatedCard);

  // Accumulate quality breakdown
  switch (result.quality) {
    case 5:
      _perfectCount++;
    case 4:
      _hesitationCount++;
    case 2:
      _struggledCount++;
    default:
      _failedCount++;
  }

  // Track earliest next due date
  final nextDue = result.updatedCard.nextReviewDate.value;
  if (_earliestNextDue == null || nextDue.isBefore(_earliestNextDue!)) {
    _earliestNextDue = nextDue;
  }
}
```

Note: The switch uses Dart 3 exhaustive pattern syntax (no `break` needed). The `result != null` guard is already present in the existing code — the stat accumulation goes inside it. The `default` case handles any unexpected quality value by counting it as failed.

Update all three `DrillSessionComplete` construction sites to use `_buildSummary()`:
- `_handleLineComplete()` — when session is complete
- `skipCard()` — when session is complete
- `build()` — early return for empty due cards (use `SessionSummary` with all zeros and `Duration.zero`)

Depends on: Step 3.

### 5. Replace `_buildSessionComplete` with enhanced summary UI

**File:** `src/lib/screens/drill_screen.dart` (modify)

Rewrite `_buildSessionComplete()` to show full session summary:
- Header: check icon + "Session Complete" heading (keep existing)
- Cards completed + skipped counts (keep existing)
- Session duration (formatted as "Xm Ys")
- Mistake breakdown rows: Perfect/Hesitation/Struggled/Failed with color-coded indicators (only show if cards were completed)
- Next due date preview (formatted as "Tomorrow", "In X days", or date)
- Done button (keep existing)

Wrap in `SingleChildScrollView` to handle small screens.

Add helper methods on `DrillScreen`:
- `_formatDuration(Duration)` — "Xm Ys" or "Xs" if under 1 minute
- `_buildBreakdownRow(context, label, count, color)` — row with colored dot, label, count
- `_formatNextDue(DateTime)` — relative date string

Depends on: Steps 2, 4.

### 6. Update existing tests for new `DrillSessionComplete` shape

**File:** `src/test/screens/drill_screen_test.dart` (modify)

Update tests that check `DrillSessionComplete` or its rendered text:
- "shows session complete when no cards are due" — verify summary fields
- "skip button advances to session complete on single card" — verify skip count in summary
- Any other tests constructing `DrillSessionComplete` directly

Depends on: Steps 2, 4.

### 7. Add new widget tests for session summary statistics

**File:** `src/test/screens/drill_screen_test.dart` (modify)

Add test group `'DrillScreen - session summary'`:
- Shows mistake breakdown after completing cards
- Shows session duration text
- Shows next due date preview
- Hides breakdown when all cards skipped (no completions)

Depends on: Steps 5, 6.

## Risks / Open Questions

1. **`DateTime.now()` in tests.** Session duration will be near-zero in tests since `DateTime.now()` uses real wall clock. Accept near-zero durations and verify the text widget exists rather than checking exact values. Duration formatting can be unit-tested separately.

2. **Quality values 0 and 3 are never produced.** `Sm2Scheduler.qualityFromMistakes()` only returns 1, 2, 4, or 5. The `switch` in Step 4 uses `default` for the failed case to safely handle any unexpected quality values.

3. **`ReviewCardsCompanion.nextReviewDate` is a `Value<DateTime>`.** Drift `Value` wrapper — access via `.value`. Always set by `Sm2Scheduler.updateCard()`, so never `Value.absent()`.

6. **Next due date preview shows earliest date.** The acceptance criterion "next due date preview" is intentionally implemented as the earliest `nextReviewDate` across all completed cards. This gives the user the most actionable information: "when do I next need to review?" Showing all dates or a range would add complexity without clear value.

4. **Three construction sites for `DrillSessionComplete`.** Extract `_buildSummary()` helper (Step 3) to avoid duplication across `_handleLineComplete()`, `skipCard()`, and `build()`.

5. **File size.** `drill_screen.dart` is already 553 lines and will grow. This is acceptable for CT-5 since the data class, controller logic, and UI are tightly coupled. Splitting into separate files could be a follow-up task.
