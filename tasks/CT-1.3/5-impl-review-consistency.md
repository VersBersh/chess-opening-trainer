# CT-1.3 Implementation Review

## Verdict

**Approved with Notes**

## Progress

- [x] **Step 1** -- Add `flutter_riverpod` dependency to `src/pubspec.yaml`
  - `flutter_riverpod: ^2.6.1` added correctly at line 44.
- [x] **Step 2** -- Wrap app in `ProviderScope`, define repository providers in `main.dart`
  - `main()` is async. `ProviderScope` wraps `ChessTrainerApp` with `overrideWithValue` for both repository providers. Providers use the `throw UnimplementedError` pattern as planned.
- [x] **Step 3** -- Define drill state sealed class hierarchy
  - All five states defined: `DrillLoading`, `DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`. `DrillCardStart.introMoves` field from plan is omitted (not needed -- controller reads directly from engine). `CardComplete` omitted as planned.
- [x] **Step 4** -- Implement `DrillController` as `AsyncNotifier`
  - Correctly extends `AutoDisposeFamilyAsyncNotifier<DrillScreenState, int>`. All planned methods implemented: `build`, `_startNextCard`, `_autoPlayIntro`, `processUserMove`, `_revertAfterMistake`, `_handleLineComplete`, `skipCard`. `_preMoveFen` approach for SAN derivation implemented correctly.
- [x] **Step 5** -- Expose `ChessboardController` via the notifier
  - `boardController` is a public field on `DrillController`, accessed via `ref.read(...notifier).boardController` (Option A as planned).
- [x] **Step 6** -- Build the `DrillScreen` widget
  - `ConsumerWidget` with state-driven rendering. Scaffold with AppBar, ChessboardWidget, and status text. All states handled in `_buildForState` switch.
- [x] **Step 7** -- Implement feedback visuals (arrow and X icon)
  - Green arrow for wrong moves, blue arrow for sibling corrections. Red `Circle` shape + `Annotation(symbol: 'X')` for genuine wrong moves. Dual approach documented in impl-notes deviation #1.
- [x] **Step 8** -- Implement intro move auto-play timing
  - `_autoPlayIntro` with 300ms delays. Generation counter (`_cardGeneration`) replaces the plan's `_isActive` boolean -- documented as impl-notes deviation #5. Correctly handles the entirely-auto-played-line edge case.
- [x] **Step 9** -- Implement mistake revert timing
  - `_revertAfterMistake` with 1500ms delay. Checks `_isStale(gen)` before applying revert. Restores `_preMoveFen` and sets `DrillUserTurn`.
- [x] **Step 10** -- Wire navigation from `HomeScreen` to `DrillScreen`
  - `_repertoireId` state field added. Loaded in `_loadDueCount` from first repertoire. `_startDrill` navigates with `Navigator.push`. Due count refreshed on return via `.then((_) => _loadDueCount())`.
- [x] **Step 11** -- Create dev seed function
  - `seedDevData()` in `dev_seed.dart`. Creates branching tree with 4 leaf nodes. All leaves get review cards due today. Idempotent (checks for existing repertoires). Called in `main()` gated behind `kDebugMode`.
- [x] **Step 12** -- Write widget tests
  - 10 test cases covering: board orientation (white/black), intro auto-play, correct user move, arrow on wrong move, X annotation on wrong move, arrow-only on sibling correction, revert after mistake, card advancement, progress indicator, empty queue, skip button. Missing: entirely-auto-played-line edge case (documented in impl-notes follow-up #2).
- [x] **Step 13** -- Handle session end screen
  - "Session Complete" heading, cards-reviewed count, conditional skipped-cards count, "Done" button with `Navigator.pop()`.

## Issues

### 1. (Minor) `DrillLoading` state is dead code

**Files:** `src/lib/screens/drill_screen.dart` lines 23-25 (class), lines 355-359 (widget case)

The `DrillLoading` state class is defined and handled in `_buildForState`, but it is never emitted by the controller. The `build` method returns either `DrillSessionComplete` or `DrillCardStart` directly. The Riverpod `AsyncValue.loading` state (handled by `asyncState.when(loading: ...)` at line 331) covers the loading phase. The `DrillLoading` case inside `_buildForState` (which runs inside the `data:` callback) can never be reached.

**Suggestion:** Remove `DrillLoading` from the sealed class and its handling in `_buildForState`. Alternatively, keep it if there is a planned future use (e.g., transitional state between cards), but document why it exists.

### 2. (Minor) Missing staleness check in `_handleLineComplete` after `await`

**File:** `src/lib/screens/drill_screen.dart` lines 282-298

After `await _reviewRepo.saveReview(result.updatedCard)` (line 285), there is no `_isStale(gen)` check before mutating `_completedCards`, setting state, or calling `_startNextCard()`. If the user navigates away (triggering disposal) while the database write is in flight, the subsequent `state = AsyncData(...)` assignment could throw on a disposed notifier.

In practice, the `autoDispose` cleanup sets `_isDisposed = true`, and `_startNextCard` -> `_autoPlayIntro` would bail out via `_isStale`. The risk is limited to the `state =` assignment on line 290-294 or 296 after disposal. This is unlikely to cause user-visible issues but could produce a framework error in debug mode.

**Suggestion:** Capture `final gen = _cardGeneration` at the start of `_handleLineComplete` and add `if (_isStale(gen)) return;` after the `await` on line 285.

### 3. (Minor) No feedback state set when `sanToMove` returns null for expected move

**File:** `src/lib/screens/drill_screen.dart` lines 236-247, 250-260

In the `WrongMove` and `SiblingLineCorrection` cases, if `sanToMove(prePosition, result.expectedSan)` returns null, the state is not set to `DrillMistakeFeedback`, but `_revertAfterMistake` is still called. After the 1500ms delay, the board reverts and `DrillUserTurn` is restored. The user sees no visual feedback for the mistake.

This should never happen in practice because the expected SAN comes from the repertoire tree and should always be legal in the pre-move position. However, it is a silent failure mode.

**Suggestion:** Add a fallback or an assertion/log when `sanToMove` returns null. For example: `assert(expectedMove != null, 'Expected move SAN should always be legal');` or log a warning.

### 4. (Minor) `_startNextCard` not awaited in `_handleLineComplete` / `skipCard` is misleading

**File:** `src/lib/screens/drill_screen.dart` lines 296, 313

Both `_handleLineComplete` and `skipCard` call `await _startNextCard()`. But `_startNextCard` does not await `_autoPlayIntro` (fire-and-forget, line 169). So the `await` only awaits the synchronous state setup. This is functionally correct but the `await` is misleading -- it suggests the caller is waiting for the next card's intro to complete, which it is not.

**Suggestion:** Consider making `_startNextCard` a synchronous `void` method (since it does no async work after the generation-counter approach was adopted), or add a comment clarifying that the `await` returns immediately and intro plays in the background.

### 5. (Minor) `HomeScreen` creates new repository instances on each `_loadDueCount` call

**File:** `src/lib/screens/home_screen.dart` lines 28-29

Each call to `_loadDueCount()` creates fresh `LocalReviewRepository` and `LocalRepertoireRepository` instances. These are lightweight (just wrappers around the database), so this has no functional impact. But it is inconsistent with the Riverpod providers defined in `main.dart`.

**Suggestion:** This is explicitly deferred to CT-1.4 per the plan. No action needed now, but worth noting for that task.

### 6. (Minor) "1 cards skipped" -- missing singular/plural handling

**File:** `src/lib/screens/drill_screen.dart` line 539 and test line 655

The session complete screen shows `${drillState.skippedCards} cards skipped` and `${drillState.completedCards} cards reviewed` without singular/plural handling. "1 cards skipped" reads awkwardly. The test on line 655 expects this exact string.

**Suggestion:** Use `card` vs `cards` based on count, e.g. `'${n} card${n == 1 ? '' : 's'} skipped'`. Low priority, purely cosmetic.

### 7. (Minor) Test missing for entirely auto-played line edge case

**File:** `src/test/screens/drill_screen_test.dart`

The plan (Step 12) lists testing for the entirely-auto-played-line edge case, and the plan's Risk #6 specifically calls it out. The impl-notes (follow-up #2) acknowledge this gap. While the `DrillEngine` unit tests may cover this, the widget-level test is absent.

**Suggestion:** Add a widget test with a very short line (e.g., 1-2 moves) that is entirely auto-played, verifying that `_handleLineComplete` fires and session-complete is reached without user interaction.
