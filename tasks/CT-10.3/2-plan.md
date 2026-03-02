# CT-10.3: Implementation Plan

## Goal

In Free Practice mode, replace the automatic session-end with a "Keep Going" prompt that reshuffles the same card set and starts a new pass. When the user taps "Finish," show a cumulative session summary (using `DrillSessionComplete`) before final dismissal. Regular Drill mode's session-end behavior remains unchanged.

## Steps

### Step 1: Add a new `DrillPassComplete` state variant

**File:** `src/lib/screens/drill_screen.dart`

Add a new class to the `DrillScreenState` sealed hierarchy:

```dart
/// Emitted when all cards in a Free Practice session have been reviewed
/// but the user has not yet chosen to continue or exit.
class DrillPassComplete extends DrillScreenState {
  final int completedCards;
  final int totalCards;
  const DrillPassComplete({
    required this.completedCards,
    required this.totalCards,
  });
}
```

This state is distinct from `DrillSessionComplete`: it does not carry a full `SessionSummary` and is only emitted in Free Practice mode. It represents the pause point between passes.

**Rationale for a new state variant rather than reusing `DrillSessionComplete` with a flag:** The session summary screen has a fundamentally different layout (breakdown rows, duration, "Done" button). The "Keep Going" screen is intentionally minimal (a message and two buttons). Mixing them would require conditional branching inside `_buildSessionComplete`, and the `SessionSummary` would need to be built prematurely (the session is not truly over yet). A dedicated state keeps both code paths clean and follows the existing sealed-class pattern.

### Step 2: Add a `reshuffleQueue` method to `DrillEngine`

**File:** `src/lib/services/drill_engine.dart`

Add a public method that reshuffles the current card queue and resets the session index, reusing the existing `replaceQueue` machinery:

```dart
void reshuffleQueue() {
  final cards = List.of(_session.cardQueue);
  cards.shuffle();
  replaceQueue(cards);
}
```

This creates a mutable copy (since `cardQueue` may contain the same list reference being mutated), shuffles it, and delegates to `replaceQueue()` which resets the index and clears card/color state.

**Why add a `reshuffleQueue` method rather than calling `replaceQueue` directly from the controller?** While `DrillEngine.session` is publicly exposed, encapsulating the copy-shuffle-replace sequence in a single method provides a semantically clear convenience API for the "Keep Going" use case. The controller would otherwise need to reach into `engine.session.cardQueue`, copy the list, shuffle it, and call `replaceQueue` — three steps that always go together and are better expressed as a single intent.

### Step 3: Modify `_handleLineComplete` and `skipCard` to emit `DrillPassComplete` for Free Practice

**File:** `src/lib/screens/drill_screen.dart`

In `DrillController._handleLineComplete()`, change the existing session-complete branch:

```dart
if (_engine.isSessionComplete) {
  state = AsyncData(DrillSessionComplete(summary: _buildSummary()));
}
```

to:

```dart
if (_engine.isSessionComplete) {
  if (_isExtraPractice) {
    state = AsyncData(DrillPassComplete(
      completedCards: _completedCards,
      totalCards: _engine.totalCards,
    ));
  } else {
    state = AsyncData(DrillSessionComplete(summary: _buildSummary()));
  }
}
```

Apply the same change in `skipCard()`, which has an identical pattern.

This ensures that in Free Practice mode, reaching the end of the queue produces the intermediate `DrillPassComplete` state instead of the terminal `DrillSessionComplete`.

### Step 4: Add cumulative stat tracking and the `keepGoing` / `finishSession` methods to `DrillController`

**File:** `src/lib/screens/drill_screen.dart`

Add cumulative counter fields alongside the existing per-pass counters:

```dart
int _cumulativeCompletedCards = 0;
int _cumulativeSkippedCards = 0;
int _cumulativePerfectCount = 0;
int _cumulativeHesitationCount = 0;
int _cumulativeStruggledCount = 0;
int _cumulativeFailedCount = 0;
```

At the end of each pass (just before emitting `DrillPassComplete`), accumulate the current pass's stats into the cumulative counters.

Add a `keepGoing` method that reshuffles and starts the next pass:

```dart
Future<void> keepGoing() async {
  _engine.reshuffleQueue();
  _completedCards = 0;
  _skippedCards = 0;
  _perfectCount = 0;
  _hesitationCount = 0;
  _struggledCount = 0;
  _failedCount = 0;
  _earliestNextDue = null;
  await _startNextCard();
}
```

This resets the per-pass statistics so that the progress indicator ("Free Practice -- 1/N") starts fresh at 1/N for the new pass. The session timer (`_sessionStartTime`) is intentionally NOT reset — it tracks the total session duration across all passes.

Add a `finishSession` method that transitions to the session summary:

```dart
void finishSession() {
  // Accumulate any current-pass stats that haven't been folded in yet
  // (in case the user finishes mid-pass, though typically called from
  // DrillPassComplete where stats have already been accumulated).
  state = AsyncData(DrillSessionComplete(
    summary: SessionSummary(
      totalCards: _engine.totalCards,
      completedCards: _cumulativeCompletedCards,
      skippedCards: _cumulativeSkippedCards,
      perfectCount: _cumulativePerfectCount,
      hesitationCount: _cumulativeHesitationCount,
      struggledCount: _cumulativeStruggledCount,
      failedCount: _cumulativeFailedCount,
      sessionDuration: DateTime.now().difference(_sessionStartTime),
      isFreePractice: true,
    ),
  ));
}
```

This produces a `DrillSessionComplete` with cumulative stats across all passes. The existing `_buildSessionComplete` UI already handles `isFreePractice` (showing "Practice Complete" heading, "no SR updates" subtitle, hiding next review date). The user sees the familiar summary screen and taps "Done" to pop.

### Step 5: Build the "Keep Going" UI in the drill screen widget

**File:** `src/lib/screens/drill_screen.dart`

Add handling for `DrillPassComplete` in `_buildForState`:

```dart
case DrillPassComplete():
  return _buildPassComplete(context, ref, drillState);
```

Add a new `_buildPassComplete` method with:
- Check circle icon at top
- "Pass Complete" heading
- "X of Y cards reviewed" subtitle
- `FilledButton` with "Keep Going" text (primary action) — calls `keepGoing()` on the controller
- `TextButton` with "Finish" text — calls `finishSession()` on the controller (transitions to `DrillSessionComplete` with cumulative summary)

The layout is intentionally minimal to keep the transition seamless. The "Keep Going" button is the primary action, and "Finish" is secondary to encourage continued practice.

### Step 6: Handle the filter interaction with "Keep Going"

**File:** `src/lib/screens/drill_screen.dart`

The existing `applyFilter` method (added in CT-10.2) already handles replacing the card queue mid-session. When the user has an active label filter, `keepGoing()` should reshuffle the same filtered card set (the current contents of `_engine.session.cardQueue`), not reload from the database.

The implementation in Step 4 already handles this correctly because `reshuffleQueue()` operates on the engine's current `cardQueue` — whatever cards are currently in the queue (filtered or unfiltered) are reshuffled. No special handling is needed.

However, the filter box should remain visible on the `DrillPassComplete` screen so the user can adjust their filter before starting the next pass. Include the filter widget in the pass-complete UI if applicable.

### Step 7: Write unit tests for `DrillEngine.reshuffleQueue`

**File:** `src/test/services/drill_engine_test.dart`

Add a new test group:

```dart
group('reshuffleQueue', () {
  test('resets index and preserves card set', () {
    // Build 2-card engine, advance through both cards
    // Call reshuffleQueue
    // Verify: totalCards unchanged, currentIndex == 0, isSessionComplete == false
  });

  test('can be called after session is complete', () {
    // Complete all cards, verify isSessionComplete
    // Call reshuffleQueue
    // Verify: isSessionComplete is false, can call startCard()
  });
});
```

### Step 8: Update existing free-practice widget tests and add new "Keep Going" tests

**File:** `src/test/screens/drill_screen_test.dart`

#### 8a: Update existing tests that assert the old terminal summary flow

The following existing tests in the `'DrillScreen -- free practice'` group currently complete all cards and then assert `DrillSessionComplete` behavior (the "Practice Complete" summary screen). With the new behavior, completing all cards in Free Practice now produces `DrillPassComplete` instead. These tests must be updated:

1. **`'free practice session summary shows "Practice Complete"'`** (line ~1093): Currently completes all cards and asserts `find.text('Practice Complete')` appears (from the summary screen). Update to: complete all cards, verify `DrillPassComplete` UI appears ("Pass Complete" heading, "Keep Going" button visible). Then tap "Finish," verify transition to `DrillSessionComplete` summary showing "Practice Complete."

2. **`'free practice session summary shows SR-exempt subtitle'`** (line ~1138): Currently completes all cards and asserts `find.textContaining('no SR updates')`. Update to: complete all cards, tap "Finish" to reach the summary, then assert the SR-exempt subtitle is present on the summary screen.

3. **`'free practice session summary hides next review date'`** (line ~1181): Currently completes all cards and asserts `find.textContaining('Next review:')` is absent. Update to: complete all cards, tap "Finish" to reach the summary, then assert next review date is hidden.

4. **`'free practice without preloadedCards loads all cards'`** (line ~1224): This test checks card loading behavior, not the session-end flow. It may still pass if it does not assert summary UI. Review and update if it asserts any session-complete state.

#### 8b: Add new "Keep Going" flow tests

Add tests inside the existing `'DrillScreen -- free practice'` group:

1. **"Keep Going" button appears after all cards reviewed in free practice**: Complete all cards. Verify "Keep Going" button is visible and that we are NOT on the session summary screen (no "Done" button visible).
2. **Tapping "Keep Going" starts a new pass**: After reaching `DrillPassComplete`, tap "Keep Going". Verify transition back to card play and progress indicator resets.
3. **"Finish" button shows session summary**: After reaching `DrillPassComplete`, tap "Finish". Verify transition to `DrillSessionComplete` summary screen with "Practice Complete" heading and cumulative stats.
4. **Regular drill mode does NOT show "Keep Going"**: Complete all cards in regular drill. Verify `DrillSessionComplete` is shown and "Keep Going" is NOT visible.
5. **Multiple passes work**: Complete all cards, tap "Keep Going", complete again, verify "Keep Going" appears again.
6. **Cumulative stats in summary after multiple passes**: Complete all cards (pass 1), tap "Keep Going", complete all cards (pass 2), tap "Finish". Verify the summary shows cumulative `completedCards` equal to the sum across both passes.

## Risks / Open Questions

1. **Cumulative stat tracking adds controller complexity.** Maintaining two sets of counters (per-pass and cumulative) adds surface area. However, the alternative — not resetting per-pass counters and always showing cumulative progress — would make the progress indicator ("3/5") misleading during subsequent passes. The two-counter approach keeps per-pass UX clean while enabling an accurate final summary.

2. **Filter + Keep Going interaction.** If the user changes the filter on the `DrillPassComplete` screen, the `applyFilter` method will replace the queue and start a new card immediately (transitioning out of `DrillPassComplete`). This is arguably fine behavior — equivalent to "Keep Going with a different filter." However, the cumulative stats should still be accumulated before the filter triggers the transition away from `DrillPassComplete`.

3. **Progress indicator semantics across passes.** The plan resets `_completedCards` and progress counters on "Keep Going" so the indicator shows "1/N" for the new pass. Resetting per-pass is more intuitive for the "keep going" mental model.

4. **Session timer.** The session start time is not reset between passes, so the summary reflects total time. This seems correct for cramming sessions.

5. **Interaction with CT-10.2.** The `_selectedLabels` field on `DrillController` is an instance field that persists across state emissions — it is not cleared when `DrillPassComplete` is emitted. This is correct and no special handling is needed.

6. **Review Issue 3 note (encapsulation rationale).** The review flagged that the Step 2 rationale incorrectly claimed `DrillEngine.session` was private. This was inaccurate — `session` is a public getter (line 89 of `drill_engine.dart`). The rationale has been corrected to describe `reshuffleQueue` as a semantic convenience API rather than an encapsulation boundary.
