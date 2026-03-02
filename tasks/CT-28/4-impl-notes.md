# CT-28: Implementation Notes

## Files Modified

- **`src/lib/models/repertoire.dart`** — Added `normalizePositionKey()` static method that strips halfmove clock and fullmove number from FEN strings, producing EPD-like position keys. Added `movesByPositionKey` field (a `Map<String, List<RepertoireMove>>`) built during `build()` using the normalized key. Added `getChildrenAtPosition(String positionKey)` method that returns all child moves of all nodes whose normalized FEN matches.

- **`src/lib/services/drill_engine.dart`** — Added FEN-based transposition fallback in `submitMove()` after the existing tree-structural sibling check (lines 214-228). When the fast-path tree-structural check finds no sibling match, the code normalizes the parent position's FEN, looks up all children at that position via `getChildrenAtPosition()`, and checks if the user's SAN matches any transposition sibling. Returns `SiblingLineCorrection` if found, otherwise falls through to `WrongMove`.

- **`src/test/services/drill_engine_test.dart`** — Added new test group `'submitMove -- transposition sibling detection'` (after the existing sibling line correction group) with 4 tests: (1) transposition move detected as sibling-line correction, (2) non-repertoire move at transposition position is still a genuine mistake, (3) tree-structural siblings still detected via fast path (regression guard), (4) `normalizePositionKey` unit test verifying stripping of move counters and preservation of board/turn/castling/ep differences.

## Deviations from Plan

- **Test fix:** The "tree-structural siblings are still detected (fast path)" test initially submitted `d4` and `c4` before the branch point, but with the test's single-root-move tree, intro auto-plays those moves (introEndIndex = 4). Fixed to play directly at the branch point.

## Follow-up Work

None identified during implementation.
