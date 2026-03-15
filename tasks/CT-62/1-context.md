# CT-62: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/services/drill_engine.dart` | Core drill business logic. Contains `submitMove()` which classifies user moves as correct, wrong, or sibling-line correction. Already has both tree-structural and FEN-based transposition sibling detection implemented. |
| `src/lib/models/repertoire.dart` | Defines `RepertoireTreeCache` -- eagerly-loaded indexed view of the move tree. Provides `getChildren()`, `getChildrenAtPosition()`, `normalizePositionKey()`, `movesByPositionKey`, and `movesById` lookups. |
| `src/lib/models/review_card.dart` | Defines `DrillSession` and `DrillCardState` -- session and per-card state tracked during drills. |
| `src/lib/repositories/local/database.dart` | Drift database schema defining `RepertoireMoves` and `ReviewCards` tables. `RepertoireMove` has `id`, `parentMoveId`, `fen`, `san`, `label`, `sortOrder`. |
| `src/test/services/drill_engine_test.dart` | Comprehensive tests for `DrillEngine`. Already includes a `submitMove -- transposition sibling detection` group with tests for transposition detection, genuine mistakes at transposition positions, and structural sibling regression. |
| `src/test/models/repertoire_tree_cache_test.dart` | Tests for `RepertoireTreeCache`. Contains `buildLine()` helper and tests for label management, notation, and label conflicts. |
| `features/drill-mode.md` | Feature spec for drill mode. Defines sibling-line correction behavior: moves existing in the repertoire at the current position but belonging to a different line should not count as mistakes. |

## Architecture

### Drill Engine Subsystem

The drill engine (`DrillEngine`) is a pure business-logic service with no database access, no Flutter dependencies, and no UI awareness. It manages drill session state:

1. **Card queue**: A `DrillSession` holds an ordered list of `ReviewCard` objects (each pointing to a leaf move in the repertoire tree). The engine processes them one at a time.

2. **Line reconstruction**: When a card starts, `_treeCache.getLine(leafMoveId)` walks from the leaf to the root and returns the full move sequence. This is the path the user must reproduce.

3. **Intro moves**: The engine auto-plays intro context up to a branch point or a cap of 3 user moves, whichever comes first.

4. **Move validation (`submitMove`)**: When the user plays a move:
   - If it matches the expected move in the line, it's **correct**.
   - If wrong, the engine checks for **sibling-line correction** (a repertoire move at this position, just from a different line). This uses two mechanisms:
     - **Tree-structural check (fast path)**: Looks at `getChildren(parentMoveId)` for siblings sharing the same tree parent.
     - **FEN-based transposition check (fallback)**: Gets the parent's FEN, normalizes it (strips halfmove clock and fullmove number), and calls `getChildrenAtPosition(positionKey)` to find moves from any tree node at the same board position.
   - If neither check matches, it's a **genuine mistake** (mistake counter increments).

5. **Scoring**: After the user plays through the entire line, SM-2 quality is derived from the mistake count and used to schedule the next review.

### RepertoireTreeCache

The tree cache is an in-memory index built from a flat list of `RepertoireMove` objects. Key data structures:

- `movesById`: O(1) lookup by move ID.
- `childrenByParentId`: Maps parent ID to sorted child list (tree-structural children).
- `movesByPositionKey`: Maps normalized FEN (first 4 fields: board/turn/castling/en-passant) to all moves arriving at that position. This enables transposition detection by grouping moves that reach the same board state regardless of move order.
- `rootMoves`: Moves with no parent (first moves of lines).

The `getChildrenAtPosition(positionKey)` method aggregates children of all nodes matching the position key, returning every repertoire move available from that position across all tree paths.

### Key Constraint

`normalizePositionKey()` strips the halfmove clock and fullmove number from FEN strings. This is critical because transposition-equivalent positions may differ in these counters (e.g., `d4 Nf6 c4 e6` vs `c4 e6 d4 Nf6` reach the same position but the halfmove clock differs after a pawn push vs a knight move).
