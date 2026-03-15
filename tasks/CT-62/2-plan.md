# CT-62: Implementation Plan

## Goal

Enhance drill engine sibling detection so that moves reachable via transposition (same board position reached through different move orders) are recognized as sibling-line corrections rather than genuine mistakes.

## Current State: Already Implemented

Investigation of the codebase reveals that **this feature is already fully implemented**. All acceptance criteria are met by existing code:

### 1. Transposition-aware sibling detection in `DrillEngine.submitMove()`

**File:** `src/lib/services/drill_engine.dart`, lines 200-232

The `submitMove()` method already performs two-stage sibling detection:

1. **Tree-structural check (fast path, lines 201-212):** Checks `getChildren(parentMoveId)` for siblings sharing the same tree parent. This covers the common non-transposition case.

2. **FEN-based transposition check (fallback, lines 214-228):** Gets the parent move's FEN (or `kInitialFEN` for root), normalizes it via `normalizePositionKey()` to strip halfmove clock and fullmove number, then calls `getChildrenAtPosition(positionKey)` to find all repertoire moves from any node at the same board position. If the user's move matches any of those, it returns `SiblingLineCorrection` instead of `WrongMove`.

### 2. Supporting infrastructure in `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

- `movesByPositionKey` map (line 24): Built during `RepertoireTreeCache.build()`, indexes all moves by normalized FEN.
- `normalizePositionKey()` (lines 40-49): Strips halfmove clock and fullmove number, keeping only board/turn/castling/en-passant.
- `getChildrenAtPosition()` (lines 109-120): Aggregates children of all nodes matching a position key.

### 3. Unit tests

**File:** `src/test/services/drill_engine_test.dart`, lines 459-583

The `submitMove -- transposition sibling detection` test group covers:

- **Transposition move detected as sibling-line correction** (line 482): Two lines (`d4 Nf6 c4 e6 Nc3` and `c4 e6 d4 Nf6 Nf3`) reach the same position. Playing `Nf3` when `Nc3` is expected returns `SiblingLineCorrection` with no mistake increment.
- **Non-repertoire move is still a genuine mistake** (line 502): Playing `e4` at the transposition position returns `WrongMove` with mistake count incremented.
- **Tree-structural siblings still detected (regression guard)** (line 516): A structural sibling added under the same parent is detected via the fast path without needing the FEN fallback.
- **`normalizePositionKey` unit tests** (line 551): Verifies that FENs differing only in move counters produce the same key, while FENs differing in board position or side-to-move produce different keys.

## Steps

No implementation work is needed. The task can be closed as already complete.

If any additional verification is desired:

1. **Run existing tests** to confirm they pass:
   ```
   cd src && flutter test test/services/drill_engine_test.dart
   ```

2. **Run tree cache tests** to confirm position-key infrastructure is sound:
   ```
   cd src && flutter test test/models/repertoire_tree_cache_test.dart
   ```

## Risks / Open Questions

- **None.** The implementation matches the task description exactly. The two-stage detection (tree-structural fast path + FEN-based transposition fallback) ensures both structural siblings and transposition siblings are caught, while genuine mistakes still increment the counter.

- The one edge case worth noting: if the initial position itself has a transposition (i.e., `parentMoveId == null`), the code uses `kInitialFEN` as the parent FEN. Since there is only one initial position in standard chess, this path is effectively a no-op for the transposition check, which is correct -- all root moves are already covered by the `_treeCache.rootMoves` structural check.
