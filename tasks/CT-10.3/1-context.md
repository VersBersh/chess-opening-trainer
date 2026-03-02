# CT-10.3: Context

## Relevant Files

- **`src/lib/screens/drill_screen.dart`** — Contains the `DrillController` (Riverpod AsyncNotifier), all `DrillScreenState` sealed class variants (`DrillLoading`, `DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`, `DrillSessionComplete`, `DrillFilterNoResults`), the `DrillScreen` widget, `DrillConfig`, and `SessionSummary`. The `_handleLineComplete()` and `skipCard()` methods emit `DrillSessionComplete` when the engine says the session is done. The `_buildSessionComplete()` method renders the end-of-session UI with a "Done" button.
- **`src/lib/services/drill_engine.dart`** — Pure business-logic engine. Manages card queue progression, move validation, and scoring. Exposes `isSessionComplete`, `replaceQueue()`, `session` (gives access to `cardQueue`). Has no UI or database awareness.
- **`src/lib/models/review_card.dart`** — Defines `DrillSession` (holds `cardQueue`, `currentCardIndex`, `isExtraPractice`, `resetQueue()`) and `DrillCardState`.
- **`features/free-practice.md`** — Spec defining the "Keep Going" button behavior: reshuffles the same card set, indefinite passes, session only ends on explicit exit.
- **`features/drill-mode.md`** — Spec for regular drill mode, which should be unaffected by this change (session ends normally after all due cards).
- **`src/test/services/drill_engine_test.dart`** — Unit tests for `DrillEngine`. Tests use `buildLine`, `buildReviewCard`, `buildEngine` helpers.
- **`src/test/screens/drill_screen_test.dart`** — Widget tests for `DrillScreen`. Uses `FakeRepertoireRepository`, `FakeReviewRepository`, and `buildTestApp()` helpers. Has groups for session complete, line labels, and free practice.
- **`src/test/screens/drill_filter_test.dart`** — Tests for the filter system introduced in CT-10.2. Tests `replaceQueue` and `resetQueue` behavior.

## Architecture

The drill subsystem follows a three-layer pattern:

1. **Model layer** (`review_card.dart`): `DrillSession` holds the mutable card queue and index. `DrillCardState` tracks per-card progress (current move index, mistake count). These are plain Dart classes with no Flutter or DB dependencies.

2. **Engine layer** (`drill_engine.dart`): `DrillEngine` takes a card list and `RepertoireTreeCache` at construction. It orchestrates card lifecycle: `startCard()` initializes a card, `submitMove()` validates user moves, `completeCard()` scores and advances, `skipCard()` advances without scoring. It reports `isSessionComplete` when `currentCardIndex >= cardQueue.length`. The engine also has `replaceQueue()` (added by CT-10.2) which delegates to `DrillSession.resetQueue()` to swap cards mid-session.

3. **Controller/UI layer** (`drill_screen.dart`): `DrillController` is a Riverpod `AutoDisposeFamilyAsyncNotifier` keyed on `DrillConfig`. It wraps the engine and adds async concerns: board controller animations, intro auto-play with generation-based cancellation (`_cardGeneration` / `_isStale(gen)`), SR persistence, and state emission. The screen state is a sealed class hierarchy. The `DrillScreen` widget is a `ConsumerWidget` that pattern-matches on state variants to build the UI.

**Key constraint for this task**: The "Keep Going" behavior must only activate in Free Practice mode (`isExtraPractice = true`). Regular drill mode must continue to emit `DrillSessionComplete` and end the session when all due cards are reviewed. The existing `DrillEngine.replaceQueue()` method provides the exact mechanism needed to reshuffle the same cards and reset the index.

**Current session-end flow**: When `_engine.isSessionComplete` is true after `completeCard()` or `skipCard()`, the controller emits `DrillSessionComplete(summary: _buildSummary())`. The UI renders a summary screen with a "Done" button that calls `Navigator.of(context).pop()`. There is no intermediate "keep going" option.
