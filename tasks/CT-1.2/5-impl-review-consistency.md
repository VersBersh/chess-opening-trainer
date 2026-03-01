# CT-1.2 Implementation Review — Plan Consistency

## Verdict

**Approved with Notes**

The implementation faithfully follows the plan across all 9 steps. The DrillEngine class, its result types, and the 29 unit tests are correct, well-structured, and consistent with the codebase conventions. All issues raised in the plan review (3-plan-review.md) were addressed. The deviations from the plan (multi-card test fixture redesign, const constructors on all result classes) are justified improvements. Two minor issues are noted below.

## Progress

- [x] **Step 1: Create `drill_engine.dart` with result types** -- Sealed `MoveResult` hierarchy (`CorrectMove`, `WrongMove`, `SiblingLineCorrection`) and `CardResult` are defined with const constructors and correct fields. Imports match the plan.
- [x] **Step 2: Implement DrillEngine constructor and session initialization** -- Constructor accepts `cards`, `treeCache`, `isExtraPractice`. Creates `DrillSession`, stores fields as specified. All read-only getters present and correct.
- [x] **Step 3: Implement `_isUserMoveAtIndex` and `_deriveUserColor`** -- Both helpers match the plan's logic exactly.
- [x] **Step 4: Implement `_computeIntroEndIndex`** -- Algorithm matches the plan's pseudocode: walks the line, counts user moves, detects branch points via `getChildren`/`rootMoves`, caps at 3 user moves, finds next user move after cap.
- [x] **Step 5: Implement `startCard()` and `introMoves` getter** -- `startCard()` includes the assertion guard, builds `DrillCardState` correctly. `introMoves` getter has the doc comment requested in plan review issue #3.
- [x] **Step 6: Implement `submitMove(String san)`** -- Logic matches the plan exactly: correct move advances index and auto-plays opponent response, sibling-line detection via `getChildren(parentMoveId)`, wrong move increments `mistakeCount`. Assertion guard from plan review issue #2 is present.
- [x] **Step 7: Implement `completeCard()`** -- Extra practice returns null, normal mode calls `Sm2Scheduler.qualityFromMistakes` and `updateCard`, advances session, clears state.
- [x] **Step 8: Implement `skipCard()`** -- Advances index and clears state as specified.
- [x] **Step 9: Write unit tests** -- 29 tests across 7 groups covering all planned scenarios. Test helpers (`buildLine`, `buildReviewCard`, `buildEngine`) use dartchess for realistic FENs. All plan review issues addressed: entirely-auto-played test (issue #1), submitMove assertion (issue #2), introMoves doc comment (issue #3), single-branch-no-ambiguity test (issue #4), const constructors (issue #5).

## Issues

### 1. Minor -- Test name misleading at line 305 of `drill_engine_test.dart`

**File:** `C:\code\misc\chess-trainer\src\test\services\drill_engine_test.dart`, line 305

The test is named `'correct move on user turn without opponent follow-up returns no opponentResponse'` but the test body actually exercises the full line: it first asserts that Nf6 DOES return an `opponentResponse` (O-O at line 323-325), then Be7 also returns an `opponentResponse` (Re1 at line 329), and only the final move b5 has no `opponentResponse` because the line is complete. The name suggests the test is about a single move without an opponent follow-up, but it is really an end-to-end test of a multi-move black line.

**Suggested fix:** Rename to something like `'plays through entire black line with opponent responses and final completion'` or split into separate tests for the "with opponent response" and "line complete without opponent response" cases.

### 2. Minor -- Multi-card test fixture code duplication in `drill_engine_test.dart`

**File:** `C:\code\misc\chess-trainer\src\test\services\drill_engine_test.dart`, lines 543-588, 600-709

The "Skip/defer" and "Session progress" groups each independently construct the same 2-line tree (whiteLine9 + b5/Bb3 branch) with identical position-playing boilerplate. This pattern appears three times in total (skip test, session progress test, multiple cards test).

**Suggested fix:** Extract a shared helper (e.g., `buildTwoCardEngine()`) at the top of `main()` alongside the existing line fixtures, or build the branch moves as reusable fixtures like `whiteLine9`. This would reduce ~60 lines of duplication.
