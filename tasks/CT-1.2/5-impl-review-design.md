# CT-1.2 Design Review

## Verdict: Approved with Notes

The implementation is clean, well-structured, and follows the plan faithfully. `DrillEngine` is a focused, pure business-logic service with no Flutter or database dependencies, making it highly testable. The sealed class hierarchy for `MoveResult` is idiomatic Dart. The test suite is thorough and covers the specified scenarios. The issues below are all Minor -- none require changes before merge, but addressing them would improve maintainability.

## Issues

### 1. (Minor) DRY -- Card-advance cleanup repeated three times

**Principle:** DRY / Extract Method
**File:** `C:\code\misc\chess-trainer\src\lib\services\drill_engine.dart`, lines 183-186, 193-196, 206-209

The three-line sequence `_session.currentCardIndex++; _currentCardState = null; _userColor = null;` is duplicated verbatim in `completeCard` (twice -- once in the extra-practice branch, once in the normal branch) and in `skipCard`.

**Why it matters:** If the cleanup logic ever gains a step (e.g., emitting an event, resetting a future field), all three sites must be updated in lockstep. A forgotten site would produce a subtle state bug.

**Suggested fix:** Extract a private `_advanceToNextCard()` method:

```dart
void _advanceToNextCard() {
  _session.currentCardIndex++;
  _currentCardState = null;
  _userColor = null;
}
```

Then call `_advanceToNextCard()` from `completeCard` (both branches) and `skipCard`.

---

### 2. (Minor) Hidden Coupling -- `session` getter exposes mutable internals

**Principle:** Encapsulation / Data Coupling
**File:** `C:\code\misc\chess-trainer\src\lib\services\drill_engine.dart`, line 86
**File:** `C:\code\misc\chess-trainer\src\lib\models\review_card.dart` (`DrillSession` class)

`DrillEngine.session` returns the raw `DrillSession` object, which has `currentCardIndex` as a public mutable field. Any consumer that obtains the session via this getter can mutate `currentCardIndex` directly, bypassing the engine's lifecycle methods (`completeCard`, `skipCard`). The test file already accesses `engine.session.currentCard.id` (line 694), demonstrating that callers reach through the getter into session internals.

**Why it matters:** The engine's state machine assumes it controls index advancement. An external mutation would put the engine into an inconsistent state (e.g., `_currentCardState` pointing to the wrong card). This is a temporal coupling risk: the invariant "only the engine advances the index" is enforced by convention, not by the type system.

**Suggested fix:** Either (a) remove the `session` getter entirely and expose only the specific read-only properties already present (`currentIndex`, `totalCards`, `isSessionComplete`), adding `currentCard` if needed; or (b) mark it `@visibleForTesting` if tests are the only consumer that needs it.

---

### 3. (Minor) Hidden Coupling -- `userColor` getter throws on null with `!` instead of a guarded error

**Principle:** Temporal Coupling / Fail-fast with clear errors
**File:** `C:\code\misc\chess-trainer\src\lib\services\drill_engine.dart`, line 91

`Side get userColor => _userColor!;` will throw a generic `Null check operator used on a null value` if called before `startCard()`. This is a temporal coupling: the caller must know that `startCard()` must precede any access to `userColor`, but the error message gives no indication of what went wrong.

**Why it matters:** During integration with the UI layer (CT-1.3), a misplaced call to `userColor` before `startCard()` would produce an opaque stack trace. The same pattern applies to `introMoves` (line 120) and `submitMove` (line 129), which use `_currentCardState!`.

**Suggested fix:** Add a small guard, consistent with the `assert` in `startCard()`:

```dart
Side get userColor {
  assert(_userColor != null, 'Cannot access userColor before startCard()');
  return _userColor!;
}
```

Or consider returning `Side?` and letting the caller decide, though that changes the API contract.

---

### 4. (Minor) DRY -- Branch-building boilerplate duplicated across four test groups

**Principle:** DRY
**File:** `C:\code\misc\chess-trainer\src\test\services\drill_engine_test.dart`, lines 126-143, 377-394, 406-420, 432-448, and lines 549-576, 605-628, 661-684

The "build Bc4 branch off Nc6" fixture is constructed identically in three sibling-line tests (lines 126, 377, 406, 432), and the "build b5/Bb3 branch off Ba4" fixture is constructed identically in three session/skip tests (lines 549, 605, 661). Each occurrence replays the same position manually.

**Why it matters:** The test file is 711 lines. Extracting these two fixtures into shared helpers (alongside the existing `buildLine` / `buildEngine` helpers at the top) would remove roughly 80-100 lines of duplication, improving readability and reducing the maintenance surface. The file would drop well below the 600-line mark.

**Suggested fix:** Add two helper functions at the top of the test file:

```dart
/// Builds a Bc4 branch off the 9-ply Ruy Lopez main line (branch at Nc6, id=4).
/// Returns (allMoves, branchMove).
(List<RepertoireMove>, RepertoireMove) buildBc4Branch(List<RepertoireMove> mainLine) { ... }

/// Builds a b5/Bb3 branch off the 9-ply Ruy Lopez main line (branch at Ba4, id=7).
/// Returns (allMoves, line2).
(List<RepertoireMove>, List<RepertoireMove>) buildB5Branch(List<RepertoireMove> mainLine) { ... }
```

---

### 5. (Minor) Naming -- `SiblingLineCorrection` conflates result type with corrective action

**Principle:** Naming / Reveal Intent
**File:** `C:\code\misc\chess-trainer\src\lib\services\drill_engine.dart`, line 37

The name `SiblingLineCorrection` describes what the UI should do (correct the user) rather than what happened (the user played a valid move from a different line). A name like `WrongLineMoveResult` or `SiblingLineMove` would more precisely describe the event without prescribing the UI's response.

**Why it matters:** This is a domain model class. Its name should describe the domain event, leaving the "correction" framing to the UI layer. However, this name was specified in the plan and is consistent with the feature spec, so renaming is optional.

**Suggested fix:** Consider renaming to `SiblingLineMove` if a future refactor touches this area. No action required now since the name is well-understood within the current spec.

---

### 6. (Minor) Open/Closed -- `Sm2Scheduler` is referenced as a concrete static class

**Principle:** Dependency Inversion / Open-Closed
**File:** `C:\code\misc\chess-trainer\src\lib\services\drill_engine.dart`, lines 190-192

`DrillEngine.completeCard` calls `Sm2Scheduler.qualityFromMistakes` and `Sm2Scheduler.updateCard` directly as static methods. If a different scheduling algorithm were needed (e.g., FSRS), the engine would need modification.

**Why it matters:** For a single-algorithm app this is perfectly acceptable and avoiding premature abstraction is the right call. This is noted only as a design observation: if multiple scheduling strategies become a requirement, injecting a scheduler interface via the constructor would satisfy DIP without changing the engine's API. No action needed now.
