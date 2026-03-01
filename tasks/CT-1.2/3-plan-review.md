# CT-1.2 Plan Review

## Verdict

**Approved with Notes**

The plan is well-structured, correct in its use of existing APIs, and aligns with the spec and architecture documents. The step ordering respects dependencies, the algorithm logic is sound, and the test coverage is thorough. The issues below are all Minor and can be addressed during implementation without revising the plan.

## Issues

### 1. Minor — Step 4: Intro cap auto-plays the entire line for some non-trivial lines

When the 3rd user move is followed only by opponent moves (no further user moves), `_computeIntroEndIndex` returns `lineMoves.length`, making the entire line auto-played. Example: a white line `1. e4 e5 2. Nf3 Nc6 3. Bb5 a6` (6 plies, 3 user moves) results in a fully auto-played card. This is technically correct per the spec (cap is 3 user moves, and there are no more user moves after the cap), but it means the user never interacts with the card at all — it completes instantly.

**Risk #5 in the plan already identifies this.** The drill screen (CT-1.3) must detect `introEndIndex == lineMoves.length` and call `completeCard()` immediately. The test plan (Step 9) should include this edge case explicitly — the plan mentions "Line that is entirely auto-played after intro" and "very short line" but could be clearer that this includes lines where the cap consumes all user moves, not just lines with fewer moves than the cap.

**Suggested fix:** Ensure the test fixture for "entirely auto-played" includes a line with exactly 3 user moves and no remaining user moves after the cap (e.g., 6-ply white line), not just a trivially short 1-2 move line.

### 2. Minor — Step 6: `submitMove` does not handle the edge case where `currentMoveIndex` is already at `lineMoves.length`

If `submitMove` is called after the line is already complete (e.g., due to a UI bug calling it again after `isLineComplete` was returned), `state.lineMoves[state.currentMoveIndex]` will throw a `RangeError`. The plan relies on the caller checking `isLineComplete` before calling `submitMove`, which is a reasonable contract, but adding an assertion or guard would improve robustness.

**Suggested fix:** Add an `assert(state.currentMoveIndex < state.lineMoves.length)` at the top of `submitMove`, similar to the assertion in `startCard()`.

### 3. Minor — Step 5: `introMoves` getter will crash if called before `startCard()`

The `introMoves` getter does `_currentCardState!` which will throw if `startCard()` hasn't been called. This is a reasonable contract (callers should only access `introMoves` after `startCard()`), but it's worth noting in the implementation for documentation purposes.

**Suggested fix:** No code change needed. Just add a doc comment noting that `introMoves` is only valid after `startCard()` returns.

### 4. Minor — Step 9: Missing explicit test for "line with single branch — no intro ambiguity"

The architecture's `testing-strategy.md` lists "Line with single branch — no intro ambiguity" as a drill engine test case. The plan's test groups don't include this as a named test. It's arguably covered implicitly by the "stops at cap" test (a line without branches reaches the cap), but the spec calls it out explicitly.

**Suggested fix:** Add a test case in the "Intro move calculation" group for a line with no branches at all, verifying that the intro stops at the 3 user move cap and not at a non-existent branch point.

### 5. Minor — Step 1: `MoveResult` and `CardResult` could benefit from `@immutable` or `const` constructors

The result types are data carriers that should never be mutated after creation. Using `const` constructors (where possible) or adding `@immutable` annotations would enforce this and follow Dart best practices.

**Suggested fix:** Use `final` fields on all result classes (which the plan already does via constructor parameters) and add `const` to constructors where all fields are final (e.g., `WrongMove`, `SiblingLineCorrection`). `CorrectMove` can also be const since `RepertoireMove` is a Drift data class with const constructor.
