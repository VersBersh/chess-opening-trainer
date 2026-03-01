# CT-1.2 Implementation Notes

## Files Created

- **`src/lib/services/drill_engine.dart`** — New file containing the `DrillEngine` class and all result types (`MoveResult` sealed class hierarchy: `CorrectMove`, `WrongMove`, `SiblingLineCorrection`; and `CardResult`). Implements intro move calculation, move validation, card completion scoring, and skip functionality.

- **`src/test/services/drill_engine_test.dart`** — 29 unit tests across 7 groups: intro move calculation (7 tests), submitMove correct (6 tests), submitMove wrong (3 tests), submitMove sibling-line correction (3 tests), card completion scoring (6 tests), skip/defer (2 tests), session progress (2 tests). Includes `buildLine`, `buildReviewCard`, and `buildEngine` test helpers that use dartchess to generate realistic `RepertoireMove` objects with correct FENs.

## Files Modified

None. The implementation is entirely new code.

## Plan Review Issues Addressed

1. **Issue #1 (test fixture for entirely auto-played):** Added explicit test `'entirely auto-played: line with exactly 3 user moves and no remaining user moves after cap (6-ply white line)'` using a 6-ply white line (1. e4 e5 2. Nf3 Nc6 3. Bb5 a6) where the cap consumes all 3 user moves and `introEndIndex == lineMoves.length`.

2. **Issue #2 (assertion guard in submitMove):** Added `assert(state.currentMoveIndex < state.lineMoves.length, 'Cannot submit move: line is already complete')` at the top of `submitMove`.

3. **Issue #3 (doc comment on introMoves):** Added doc comment: `/// Only valid after [startCard] has been called for the current card.`

4. **Issue #4 (test for line with single branch — no intro ambiguity):** Added test `'line with single branch -- no intro ambiguity (stops at cap)'` using a separate 10-ply line with no branches, verifying intro stops at the 3-user-move cap.

5. **Issue #5 (const constructors on result classes):** Added `const` constructors to all result classes: `MoveResult` (sealed base), `CorrectMove`, `WrongMove`, `SiblingLineCorrection`, and `CardResult`.

## Deviations from Plan

- **Multi-card test fixtures redesigned:** The plan suggested using independent lines (e.g., `1. e4` and `1. d4`) for multi-card session tests. This would cause the `RepertoireTreeCache` to have two root moves, triggering branch detection at index 0 and making `introEndIndex = 0` for all cards. Instead, multi-card tests use lines that share a common opening prefix and diverge later (e.g., both start `1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4` then diverge into `Nf6/O-O/Be7` vs `b5/Bb3`). This is more realistic and avoids the unintended branch-at-root issue.

- **`CorrectMove` constructor made `const`:** The plan review (issue #5) suggested const for `WrongMove` and `SiblingLineCorrection` specifically, noting `CorrectMove` "can also be const since `RepertoireMove` is a Drift data class with const constructor." We applied const to all result classes including the sealed base `MoveResult`, which required adding an explicit `const MoveResult()` constructor.

## Follow-up Work / Discovered Tasks

- **CT-1.3 must handle `introEndIndex == lineMoves.length`:** When a card is entirely auto-played (e.g., 6-ply white line with exactly 3 user moves), `startCard()` returns a `DrillCardState` where `currentMoveIndex >= lineMoves.length`. The drill screen must detect this and call `completeCard()` immediately without waiting for user input. This is already noted in the plan's Risk #5.

- **Transposition-aware sibling-line detection:** The current implementation uses `treeCache.getChildren(parentMoveId)` for sibling-line detection, which only catches moves branching from the same parent node. It does not detect transpositions (different tree paths reaching the same position). This is a known simplification documented in the plan's Risk #1. A future enhancement could use `treeCache.getMovesAtPosition(fen)` for broader detection.
