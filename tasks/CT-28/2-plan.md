# CT-28: Implementation Plan

## Goal

Enhance the drill engine's sibling-line detection to use FEN-based position lookup (via `RepertoireTreeCache`) in addition to tree-structural lookup, so that transposition moves are correctly classified as "sibling-line corrections" instead of "genuine mistakes."

## Steps

### 1. Add a FEN normalization utility and a normalized position index to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

The dartchess library's `Position.fen` getter produces full FEN strings including the halfmove clock and fullmove number (the last two space-separated fields). These counters differ across transposition-equivalent positions. For example, after `1. d4 Nf6 2. c4 e6` the halfmove clock is 0 (pawn move `e6`), but after the transposition `1. c4 e6 2. d4 Nf6` the halfmove clock is 1 (knight move `Nf6`), even though the board, side to move, castling rights, and en-passant square are identical. This means raw FEN strings cannot be used as position keys for transposition detection.

**1a. Add a static `normalizePositionKey` method** that strips the halfmove clock and fullmove number from a FEN string, producing an EPD-like key (board + side-to-move + castling + en-passant only).

```dart
/// Strips the halfmove clock and fullmove number from a FEN string,
/// returning the first four fields (board, turn, castling, en-passant).
///
/// This produces a position key that is identical for transposition-
/// equivalent positions regardless of the move order used to reach them.
static String normalizePositionKey(String fen) {
  int spaceCount = 0;
  for (int i = 0; i < fen.length; i++) {
    if (fen[i] == ' ') {
      spaceCount++;
      if (spaceCount == 4) return fen.substring(0, i);
    }
  }
  return fen; // Defensive: return as-is if fewer than 4 spaces
}
```

**1b. Add a second index `movesByPositionKey`** (a `Map<String, List<RepertoireMove>>`) to `RepertoireTreeCache`, built during `build()` using the normalized key. The existing `movesByFen` map remains unchanged (it uses raw FEN strings and is used elsewhere).

**1c. Add a `getChildrenAtPosition(String positionKey)` method** that returns all child moves of all nodes whose normalized FEN matches the given position key:

```dart
List<RepertoireMove> getChildrenAtPosition(String positionKey) {
  final nodesAtPosition = movesByPositionKey[positionKey];
  if (nodesAtPosition == null) return [];
  final result = <RepertoireMove>[];
  for (final node in nodesAtPosition) {
    final children = childrenByParentId[node.id];
    if (children != null) {
      result.addAll(children);
    }
  }
  return result;
}
```

**No dependencies on other steps.**

### 2. Modify `submitMove` in `DrillEngine` to use FEN-based transposition lookup

**File:** `src/lib/services/drill_engine.dart`

Replace the current sibling detection logic (lines 200-216) with an enhanced version that first checks tree-structural siblings (unchanged fast path), and if no match is found, falls back to FEN-based transposition detection using the normalized position key.

The new code:
```dart
// Wrong move -- check if it's a sibling line correction.
// First: tree-structural siblings (fast path, common case).
final parentMoveId = expectedMove.parentMoveId;
final siblingsAtPosition = parentMoveId == null
    ? _treeCache.rootMoves
    : _treeCache.getChildren(parentMoveId);

final isSiblingLine = siblingsAtPosition
    .any((m) => m.san == san && m.id != expectedMove.id);

if (isSiblingLine) {
  return SiblingLineCorrection(expectedSan: expectedMove.san);
}

// Second: FEN-based transposition lookup using normalized position keys.
// The parent's FEN is the current board position. Normalize it to strip
// move counters so transposition-equivalent positions match.
final parentFen = parentMoveId != null
    ? _treeCache.movesById[parentMoveId]!.fen
    : kInitialFEN;
final parentPositionKey = RepertoireTreeCache.normalizePositionKey(parentFen);
final transpositionChildren =
    _treeCache.getChildrenAtPosition(parentPositionKey);
final isTranspositionSibling = transpositionChildren
    .any((m) => m.san == san && m.id != expectedMove.id);
if (isTranspositionSibling) {
  return SiblingLineCorrection(expectedSan: expectedMove.san);
}

// Genuine mistake
state.mistakeCount++;
return WrongMove(expectedSan: expectedMove.san);
```

Key design decisions:
- **Tree-structural check first.** Fast path covers the common case.
- **Uniform treatment of root and non-root moves.** FEN-based fallback applies to both. For root moves, the parent position is `kInitialFEN`. In practice, all root moves are found by the tree-structural check, so the FEN fallback for root moves is a no-op. But it avoids a special case.
- **Uses `normalizePositionKey` on the parent FEN.** Strips halfmove clock and fullmove number so transposition-equivalent positions produce the same lookup key.

**Depends on:** Step 1.

### 3. Add unit tests for transposition scenarios

**File:** `src/test/services/drill_engine_test.dart`

Add a new test group `'submitMove -- transposition sibling detection'` after the existing `'submitMove -- sibling line correction'` group.

**Tests to write:**

1. **`'transposition move is detected as sibling-line correction (not mistake)'`** — Core transposition test. Two lines reach the same position via different move orders (e.g., `1. d4 Nf6 2. c4 e6` vs `1. c4 e6 2. d4 Nf6`), with different continuations. User plays the other line's move. Assert `SiblingLineCorrection` returned and `mistakeCount` remains 0. This test implicitly validates FEN normalization because the two paths produce different raw FENs (halfmove clock 0 vs 1).

2. **`'non-repertoire move at transposition position is still a genuine mistake'`** — Same tree setup, but user plays a move not in any repertoire line. Assert `WrongMove` and `mistakeCount` incremented.

3. **`'tree-structural siblings are still detected (fast path still works)'`** — Regression guard: a sibling from the same tree parent is still detected as `SiblingLineCorrection`.

4. **`'normalizePositionKey strips halfmove clock and fullmove number'`** — Directly unit-test the normalization function. Assert that two FEN strings differing only in move counters produce the same position key, and that FEN strings differing in board/turn/castling/ep produce different keys.

**Depends on:** Steps 1, 2.

### 4. Verify existing tests still pass

Run the full test suite to confirm no regressions. The tree-structural fast path is preserved, so all existing sibling detection tests should pass unchanged. The `movesByFen` map is not modified, so any code using `getMovesAtPosition(fen)` continues to work.

**Depends on:** Steps 1, 2, 3.

## Risks / Open Questions

1. **Performance of the parallel index.** The `movesByPositionKey` map doubles the FEN-based indexing memory. In typical repertoires this is negligible (a few thousand entries at most). No performance concern.

2. **`movesByFen` vs `movesByPositionKey` usage boundary.** The existing `movesByFen` map (raw FEN keys) remains for `getMovesAtPosition(fen)`, used by other parts of the codebase where exact FEN matching is intended. The new `movesByPositionKey` map is used only by `getChildrenAtPosition(positionKey)` for transposition detection. This separation avoids breaking existing behavior.

3. **Root position edge case.** The revised plan applies FEN-based lookup uniformly for both root and non-root moves. For root moves, all are found by the tree-structural check since all have `parentMoveId == null`. The FEN fallback would only matter if a non-root node also resulted in the initial position (e.g., `1. Nf3 Nf6 2. Ng1 Ng8`), which is theoretically possible but effectively never appears in opening repertoires. The uniform code path is simpler.

4. **En-passant square in normalized key.** The en-passant square is included (as it should be, since it affects legal moves). In rare cases, two transposition paths could produce the same board but with different en-passant availability. This is correct — the positions are genuinely different.
