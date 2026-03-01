# CT-1.3 Implementation Review — Design

## Verdict: Approved with Notes

The implementation is well-structured and closely follows the plan. The sealed state hierarchy, controller/widget separation, and async cancellation pattern are sound. The issues below are all Minor — nothing blocks merging.

---

## Issues

### 1. Minor — DRY: Repeated state-field construction (drill_screen.dart)

**Principle violated:** DRY / Abstraction levels

**Files:** `src/lib/screens/drill_screen.dart`, lines 141–146, 162–166, 195–199, 228–232, 238–244, 250–256, 273–277

The pattern

```dart
DrillUserTurn(
  currentCardNumber: _engine.currentIndex + 1,
  totalCards: _engine.totalCards,
  userColor: _engine.userColor,
)
```

is repeated verbatim seven times across the controller (once per state subclass constructor, but the three shared fields are copy-pasted each time). If a new shared field is added (e.g. `isExtraPractice`), every call site must be updated.

**Why it matters:** Today there are only three shared fields so the risk is modest, but each new field multiplies the number of locations to touch. A typo or omission in one site produces a subtle UI bug.

**Suggested fix:** Extract a private helper on the controller:

```dart
({int currentCardNumber, int totalCards, Side userColor}) get _cardInfo => (
  currentCardNumber: _engine.currentIndex + 1,
  totalCards: _engine.totalCards,
  userColor: _engine.userColor,
);
```

Or factor the common fields into a base class (e.g., `DrillActiveState`) that `DrillCardStart`, `DrillUserTurn`, and `DrillMistakeFeedback` extend. This is a "when it starts to hurt" change — fine to defer.

---

### 2. Minor — Temporal coupling: `_autoPlayIntro` fire-and-forget in `build()` (drill_screen.dart)

**Principle violated:** Hidden coupling (temporal)

**File:** `src/lib/screens/drill_screen.dart`, lines 148–150

```dart
// Fire-and-forget: intro plays asynchronously, updating state as it goes.
_autoPlayIntro(_cardGeneration);

return firstCardState;
```

`_autoPlayIntro` is launched without being awaited. If it throws (e.g., `sanToMove` returns `null` for every intro move due to bad data and then `_engine.currentCardState!` dereferences null), the error is silently swallowed because there is no `try/catch` and the future is not wired into Riverpod's error channel.

In `_startNextCard` (line 169) the same pattern appears.

**Why it matters:** In practice the `_isStale` guard and the null-check on `sanToMove` prevent most crashes, so the risk is low. But if a data corruption bug causes an exception during intro playback, the user sees a frozen "Playing intro moves..." state with no error feedback.

**Suggested fix:** Wrap the body of `_autoPlayIntro` in a `try/catch` that sets `state = AsyncError(...)` on failure. Alternatively, store the future and have `build()` set up an error listener. Not urgent — the current comment documents the design intent.

---

### 3. Minor — SRP: `DrillScreen` widget file contains both controller and view (drill_screen.dart)

**Principle violated:** Single Responsibility / File organisation

**File:** `src/lib/screens/drill_screen.dart` — 553 lines

The file houses the sealed state hierarchy (80 lines), the `DrillController` notifier (235 lines), and the `DrillScreen` widget (238 lines). At 553 lines it exceeds the 300-line file-size guideline.

**Why it matters:** A single file of this size is still navigable, and the plan explicitly chose this layout ("keeping it in the screen file follows the one-controller-per-screen pattern for now"). The concern is that future additions (e.g., a `DrillCardComplete` state, extra-practice mode) will push it further.

**Suggested fix:** Split into three files when the next feature touches this code:
- `drill_state.dart` — sealed class hierarchy
- `drill_controller.dart` — `DrillController` + provider
- `drill_screen.dart` — widget only

No action required now; the current co-location makes review easier during this task.

---

### 4. Minor — Dependency Inversion: `HomeScreen` instantiates concrete repositories (home_screen.dart)

**Principle violated:** Dependency Inversion Principle

**File:** `src/lib/screens/home_screen.dart`, lines 28–29

```dart
final reviewRepo = LocalReviewRepository(widget.db);
final repertoireRepo = LocalRepertoireRepository(widget.db);
```

`HomeScreen` directly depends on `LocalRepertoireRepository` and `LocalReviewRepository` (concretions), while `DrillScreen` properly reads abstract providers. This inconsistency means `HomeScreen` cannot be widget-tested with fakes without wrapping `AppDatabase`.

**Why it matters:** The plan documents this as intentional ("Leave `HomeScreen` refactoring to CT-1.4"), and the review scope is limited to CT-1.3 changes. Flagging it here for visibility since the concrete dependency was introduced (or reinforced) by the change to load `_repertoireId`.

**Suggested fix:** Defer to CT-1.4 as planned. When `HomeScreen` becomes a `ConsumerWidget`, replace these with `ref.read(repertoireRepositoryProvider)` / `ref.read(reviewRepositoryProvider)`.

---

### 5. Minor — Naming: `_isStale` could be more descriptive (drill_screen.dart)

**Principle violated:** Clean Code — Naming

**File:** `src/lib/screens/drill_screen.dart`, line 172

```dart
bool _isStale(int gen) => _isDisposed || gen != _cardGeneration;
```

"Stale" is slightly ambiguous — it could mean stale data, stale UI, etc. The method actually checks whether the current async operation should be cancelled because the controller's lifecycle or card context has changed.

**Suggested fix:** Consider `_isCancelled(int gen)` or `_shouldAbort(int gen)`. Very minor — the surrounding comment and usage make the intent clear enough.

---

### 6. Minor — Robustness: `processUserMove` does not guard against non-`DrillUserTurn` state (drill_screen.dart)

**Principle violated:** Defensive programming / Hidden coupling (semantic)

**File:** `src/lib/screens/drill_screen.dart`, line 204

`processUserMove` checks `_isDisposed` but does not verify that the current state is `DrillUserTurn`. If `ChessboardWidget` somehow fires `onMove` during `DrillCardStart` or `DrillMistakeFeedback` (e.g., due to a framework race), the controller would call `_engine.submitMove` in an unexpected state.

**Why it matters:** The widget sets `playerSide: PlayerSide.none` during non-interactive states, so chessground should not fire `onMove`. The risk is low but the guard is cheap.

**Suggested fix:** Add an early return:

```dart
Future<void> processUserMove(NormalMove move) async {
  if (_isDisposed) return;
  if (state.value is! DrillUserTurn) return;
  ...
}
```

---

## Summary

The implementation is clean, well-aligned with the plan, and exhibits good practices: sealed classes for exhaustive state handling, generation-based async cancellation, proper Riverpod lifecycle management via `ref.onDispose`, and comprehensive widget tests covering all specified scenarios. The issues above are all Minor quality-of-life improvements. None require changes before merging.
