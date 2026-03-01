# CT-2.2 Context

## Relevant Files

### Specs

- `features/line-management.md` -- Primary spec for this task. Defines board-based line entry (in-memory buffer, take-back, confirm flow), browse/edit mode toggle, board orientation as color indicator, line parity validation on confirm, branching from existing lines, and line extension behavior (old card removed, new card created with default SR state).
- `features/repertoire-browser.md` -- Defines the browser screen that hosts the edit mode toggle. Describes the "Add a Line" action (transitions to line-entry mode from the selected position) and the board interaction constraint (read-only in browse mode, interactive in edit mode).
- `architecture/models.md` -- Defines `RepertoireMove` (id, repertoire_id, parent_move_id, fen, san, label, sort_order), `RepertoireTreeCache` (in-memory indexed tree with O(1) lookups), and `ReviewCard` (leaf_move_id, SR state). Color is derived from leaf depth, not stored.
- `architecture/repository.md` -- Defines `RepertoireRepository.saveMove`, `RepertoireRepository.extendLine` (atomic: delete old card, insert moves, create new card), `RepertoireRepository.getMovesAtPosition`, `RepertoireRepository.isLeafMove`, and `ReviewRepository.saveReview`/`getCardForLeaf` for card creation.

### Source files (existing)

- `src/lib/screens/repertoire_browser_screen.dart` -- The host screen for edit mode. Contains `RepertoireBrowserState` (immutable state with copyWith), tree cache, expand/collapse state, board orientation, selected node. Has a stub "Edit" button (`onPressed: null`) in the action bar. Uses `StatefulWidget` + `setState` pattern. This file will be modified to add edit mode toggle, buffer UI, and confirm/discard flow.
- `src/lib/widgets/chessboard_widget.dart` -- Reusable board widget (CT-1.1). Accepts `ChessboardController`, `orientation`, `playerSide` (controls interactivity), `onMove` callback (invoked after a legal user move). In browse mode, `playerSide: PlayerSide.none` disables interaction. Edit mode will set `playerSide: PlayerSide.both` to accept moves from either side.
- `src/lib/widgets/chessboard_controller.dart` -- `ChangeNotifier` owning `Position` state. Key methods: `setPosition(fen)` to jump to a FEN, `playMove(move)` to play a legal move (returns bool), `resetToInitial()`. Exposes `fen`, `sideToMove`, `validMoves`, `lastMove`, `isCheck`, `isPromotionRequired(move)`. The controller will be used to replay existing moves and accept new ones during line entry.
- `src/lib/models/repertoire.dart` -- Contains `RepertoireTreeCache` with `build()`, `getLine(moveId)`, `getChildren(moveId)`, `getRootMoves()`, `isLeaf(moveId)`, `getMovesAtPosition(fen)`, `getAggregateDisplayName(moveId)`, `getMoveNotation(moveId)`, `getSubtree(moveId)`. The `getChildren` and `getMovesAtPosition` methods are central to the "follow existing tree branches" behavior during line entry.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface. `saveMove(RepertoireMovesCompanion)` returns the inserted ID. `extendLine(oldLeafMoveId, List<RepertoireMovesCompanion>)` is the atomic line extension operation. `getMovesForRepertoire(int)` for rebuilding the tree cache after a save.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite/Drift implementation. `saveMove` inserts with upsert/ignore semantics on sibling uniqueness constraint. `extendLine` runs in a transaction: deletes old card, inserts new moves with chained parent IDs, creates new card. Shows the `RepertoireMovesCompanion.insert(repertoireId:, fen:, san:, sortOrder:, parentMoveId: Value(...))` pattern.
- `src/lib/repositories/review_repository.dart` -- Abstract interface. `saveReview(ReviewCardsCompanion)` for card creation. `getCardForLeaf(int leafMoveId)` to check if a card exists for a given leaf.
- `src/lib/repositories/local/local_review_repository.dart` -- SQLite/Drift implementation. `saveReview` inserts or updates based on whether `card.id` is present. Shows `ReviewCardsCompanion.insert(repertoireId:, leafMoveId:, nextReviewDate:)` pattern for new cards with default SR values.
- `src/lib/repositories/local/database.dart` -- Drift schema. `RepertoireMoves` table with id, repertoireId, parentMoveId (nullable, cascade delete), fen, san, label (nullable), comment (nullable), sortOrder. `ReviewCards` table with id, repertoireId, leafMoveId, easeFactor (default 2.5), intervalDays (default 1), repetitions (default 0), nextReviewDate, lastQuality (nullable). Sibling uniqueness indexes: `idx_moves_unique_sibling` on (parent_move_id, san) and `idx_moves_unique_root` on (repertoire_id, san).
- `src/lib/services/chess_utils.dart` -- `sanToMove(Position, String)` utility. Parses SAN to `NormalMove`. May be useful for converting board moves to SAN during entry, though the chessboard controller already provides move objects.
- `src/lib/widgets/move_tree_widget.dart` -- Tree view widget. Displays the move tree as a scrollable list. Receives `RepertoireTreeCache` and renders `VisibleNode` entries. Read-only widget; does not need modification for edit mode, but the tree view should remain visible during editing for context.
- `src/lib/models/review_card.dart` -- Contains `DrillSession` and `DrillCardState` transient models. Not directly used by line entry, but shows patterns for transient in-memory state classes.
- `src/lib/services/drill_engine.dart` -- Reference for service-layer patterns. Pure Dart, no DB access, receives pre-loaded data. The `_deriveUserColor` method shows the convention: `lineMoves.length.isOdd ? Side.white : Side.black` for ply-based color derivation.

### Test files (reference for patterns)

- `src/test/screens/repertoire_browser_screen_test.dart` -- Widget test for the browser screen. Shows `createTestDatabase()` (in-memory Drift DB), `seedRepertoire(db, lines:, labelsOnSan:)` helper for seeding test data, `buildTestApp(db, repId)` for wrapping in `MaterialApp`. Uses `tester.pumpAndSettle()` for async data loading. This file will be extended with edit-mode tests.
- `src/test/services/drill_engine_test.dart` -- Shows `buildLine(sans, ...)` helper for hand-building `RepertoireMove` lists with correct FENs from SAN sequences.
- `src/test/models/repertoire_tree_cache_test.dart` -- Tests for `RepertoireTreeCache` methods.

### Source files (to be created)

- `src/lib/services/line_entry_engine.dart` -- Pure business-logic service for line entry. Manages the in-memory buffer, tracks which moves are existing vs. new, validates parity, and produces the list of new moves to save.

## Architecture

The line entry system is a mode within the repertoire browser screen that enables board-based move input to build new repertoire lines. It sits between the UI layer (browser screen + chessboard widget) and the repository layer (move/card persistence).

### Data flow

```
User plays move on board
        |
        v
ChessboardWidget (onMove callback)
        |
        v
LineEntryEngine (pure Dart, in-memory)
  - Check: does this SAN exist as a child of current node in tree cache?
    - YES: follow existing branch (no buffer append)
    - NO: append to buffer as new move
  - Track: boundary between existing/new moves
  - Validate: parity on confirm
        |
        v (on confirm)
RepertoireRepository.saveMove / extendLine
ReviewRepository.saveReview
        |
        v
Rebuild RepertoireTreeCache (re-enter browse mode with updated data)
```

### Key components

1. **LineEntryEngine** (to be created) -- Pure business-logic service with no DB access or Flutter dependencies. Receives the `RepertoireTreeCache` and the starting position (either root or a navigated-to node). Owns:
   - The current position in the existing tree (nullable `RepertoireMove` -- the last existing node followed)
   - The in-memory buffer of new moves (list of `{san, fen}` pairs)
   - Whether the user has diverged from the existing tree
   - Parity validation logic

2. **RepertoireBrowserScreen** (modified) -- Gets a new `isEditMode` flag in its state. When toggled:
   - The chessboard switches from `PlayerSide.none` to `PlayerSide.both`
   - The action bar shows "Confirm Line", "Take Back", and "Discard" instead of browse-mode actions
   - Board orientation's flip toggle determines the line color
   - On confirm, new moves are persisted and the tree cache is rebuilt

3. **ChessboardWidget + ChessboardController** (existing, no changes needed) -- The board already supports interactive mode via `playerSide: PlayerSide.both` and fires `onMove` callbacks. The controller's `playMove` validates legality. `setPosition` can jump to any FEN for setup.

4. **RepertoireRepository** (existing) -- `saveMove` inserts individual moves. `extendLine` handles the atomic case of extending an existing leaf (delete old card, insert chain, create new card). For new lines branching from a non-leaf node, individual `saveMove` calls are needed with chained parent IDs, followed by card creation.

### Key constraints

- **Buffer is in-memory only.** No moves are written to the database until the user confirms. If the user exits edit mode or the screen without confirming, the buffer is discarded silently.
- **Follow existing branches automatically.** When the user plays a move that already exists as a child of the current node in the tree, the engine follows it without adding to the buffer. This prevents duplicates and enables branching from arbitrary points.
- **Take-back boundary.** The user can undo buffered (new) moves, but cannot undo beyond the branch point where they diverged from the existing tree (or back past the starting position).
- **Parity validation.** On confirm, the system checks whether the leaf depth (total moves in the path) matches the board orientation. Odd ply = white, even ply = black. If mismatch, a warning dialog offers to flip the board and confirm as the other color.
- **Card creation.** A new `ReviewCard` is created for the new leaf with default SR values (ease_factor=2.5, interval_days=0 per spec / 1 per DB default, repetitions=0, next_review_date=now). If the user is extending an existing leaf, the old card is removed (handled by `extendLine`).
- **Tree cache rebuild.** After a successful save, the tree cache must be rebuilt to reflect the new moves. The screen re-enters browse mode with the updated tree.
