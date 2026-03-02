# CT-28: Context

## Relevant Files

- **`src/lib/services/drill_engine.dart`** — The drill engine service containing `submitMove()`, which is the method that needs modification. Lines 200-216 contain the sibling-line detection logic that currently uses only tree-structural lookup via `getChildren(parentMoveId)`.
- **`src/lib/models/repertoire.dart`** — Contains `RepertoireTreeCache` with `getMovesAtPosition(fen)` (line 64), `getChildren(moveId)` (line 75), `rootMoves` (line 10), and `movesById` (line 7). The FEN-based index (`movesByFen`) is already built at cache construction time (line 34).
- **`src/lib/repositories/local/database.dart`** — Drift schema defining `RepertoireMoves` table. Each `RepertoireMove` has `fen` (position *after* the move is played), `san`, `parentMoveId`, and `id`. The `fen` field is the post-move position, not the pre-move position.
- **`src/lib/repositories/local/database.g.dart`** — Generated Drift code providing the concrete `RepertoireMove` data class with `copyWith` support and all field accessors.
- **`src/lib/models/review_card.dart`** — Contains `DrillSession` and `DrillCardState`. `DrillCardState.lineMoves` is the ordered root-to-leaf path being drilled, and `currentMoveIndex` tracks where the user is.
- **`src/test/services/drill_engine_test.dart`** — Existing test file covering intro move calculation, correct/wrong/sibling-line moves, scoring, skip/defer, session progress, line labels, and reshuffle. Contains `buildLine()`, `buildReviewCard()`, and `buildEngine()` test helpers that construct realistic `RepertoireMove` objects using dartchess for accurate FEN generation.
- **`features/drill-mode.md`** — Spec defining the "Wrong Move — Sibling Line Correction" behavior: moves that exist in the repertoire at this position but belong to a different line are shown with arrow only (no X), no mistake counted. Also defines "Wrong Move — Not in Any Repertoire Line": shown with X and arrow, mistake counted.
- **`architecture/models.md`** — Documents `RepertoireTreeCache.moves_by_fen` as `Map<FEN, List<RepertoireMove>>` and `getMovesAtPosition(fen)` — "returns all moves that reach the given FEN".

## Architecture

The drill engine (`DrillEngine`) is a pure Dart business-logic service with no database access and no Flutter dependencies. It receives a `RepertoireTreeCache` (pre-built, in-memory indexed tree) and a list of `ReviewCard`s at construction time.

The `submitMove(String san)` method is the core of move validation. It compares the user's submitted SAN against the expected move at the current position in the card's line. If the SAN does not match:

1. **Tree-structural sibling check (current implementation):** Gets the parent of the expected move, then gets all children of that parent via `getChildren(parentMoveId)` (or `rootMoves` for root-level moves). If the user's SAN matches any sibling's SAN, returns `SiblingLineCorrection` (no mistake counted).

2. **Genuine mistake (fallback):** If no sibling match is found, increments `mistakeCount` and returns `WrongMove`.

The gap: the current approach only finds siblings in the tree-structural sense (moves sharing the same `parentMoveId`). It misses transpositions — where a different tree path reaches the same board position. For example, `1. d4 Nf6 2. c4` and `1. c4 Nf6 2. d4` lead to the same position. If the user is drilling one line and plays the other line's move, the current code flags it as a "genuine mistake" because the moves have different parents in the tree.

The `RepertoireTreeCache` already has full infrastructure for FEN-based lookup: `movesByFen` (a `Map<String, List<RepertoireMove>>`) is built at construction time, and `getMovesAtPosition(fen)` provides O(1) access. The key semantic: `move.fen` is the position *after* the move is played, so `getMovesAtPosition(someFen)` returns all moves that *result in* that FEN.

To detect transpositions, we need: "at the current board position (before the expected move), are there other moves in the repertoire with the user's SAN?" The current board position's FEN is the parent move's FEN (or the initial FEN for root moves). We find all repertoire nodes at that FEN, gather their children, and check for the user's SAN.
