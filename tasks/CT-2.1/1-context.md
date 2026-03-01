# CT-2.1 Context

## Relevant Files

### Specs

- `features/repertoire-browser.md` -- Primary spec for this task. Defines tree visualization (node display with SAN, move number, label, branch indicator), expand/collapse behavior, node selection, keyboard/gesture navigation, board sync, actions (focus mode, add line, delete leaf, edit label, view card stats), line list view alternative, and eager loading strategy via `RepertoireTreeCache`.
- `features/line-management.md` -- Defines labeling rules, aggregate display name derivation (concatenate labels along root-to-leaf path, joined with " -- "), browse/edit mode toggle, and card creation rules. The browser displays these derived names and provides entry points into edit mode.
- `architecture/models.md` -- Defines `Repertoire`, `RepertoireMove` (id, repertoire_id, parent_move_id, fen, san, label, sort_order), `RepertoireTreeCache` (moves_by_id, children_by_parent_id, moves_by_fen, root_moves), `ReviewCard`, `DrillSession`, `DrillCardState`.
- `architecture/repository.md` -- Defines `RepertoireRepository` (getMovesForRepertoire, getRootMoves, getChildMoves, getLineForLeaf, isLeafMove, countLeavesInSubtree) and `ReviewRepository` (getCardsForSubtree with dueOnly flag, getDueCardsForRepertoire).
- `architecture/state-management.md` -- Riverpod-based state management. Widgets never call repositories directly. Controllers/notifiers encapsulate business logic. The repertoire browser builds its own `RepertoireTreeCache` on entry. Tree is not reactive (no streams) -- cache is rebuilt when returning from line-entry mode. Navigator 1.0 for navigation.
- `architecture/testing-strategy.md` -- Lists specific browser widget tests: displays tree with expand/collapse, labeled nodes visually distinguished, tap navigates to position on board, entry point to drill/focus mode, subtree deletion confirmation shows affected counts.

### Source files (existing)

- `src/lib/models/repertoire.dart` -- Contains `RepertoireTreeCache` with `build()`, `getLine()`, `getChildren()`, `getRootMoves()`, `isLeaf()`, `getSubtree()`, `getMovesAtPosition()`. This is the core in-memory data structure the browser screen will consume.
- `src/lib/models/review_card.dart` -- Contains `DrillSession` and `DrillCardState` transient models. Not directly used by browser but defines patterns for transient in-memory state.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface with `getMovesForRepertoire(int)` used to populate the tree cache, plus `getChildMoves`, `getRootMoves`, `getLineForLeaf`, `isLeafMove`, `countLeavesInSubtree`.
- `src/lib/repositories/review_repository.dart` -- Abstract interface with `getCardsForSubtree(int moveId, {bool dueOnly, DateTime? asOf})` for computing due-card counts per subtree, and `getAllCardsForRepertoire`.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite/Drift implementation of `RepertoireRepository`. Shows patterns for custom SQL queries (recursive CTEs for line traversal, subtree counting).
- `src/lib/repositories/local/local_review_repository.dart` -- SQLite/Drift implementation of `ReviewRepository`. Shows the `getCardsForSubtree` recursive CTE pattern.
- `src/lib/repositories/local/database.dart` -- Drift database schema. `RepertoireMoves` table has id, repertoireId, parentMoveId (nullable), fen, san, label (nullable), comment (nullable), sortOrder. `ReviewCards` table has id, repertoireId, leafMoveId, easeFactor, intervalDays, repetitions, nextReviewDate, lastQuality, lastExtraPracticeDate.
- `src/lib/widgets/chessboard_widget.dart` -- Reusable board widget (CT-1.1). Accepts `ChessboardController`, `orientation`, `playerSide`, `onMove` callback, `lastMoveOverride`, `shapes`, `annotations`, `settings`. Uses `LayoutBuilder` for sizing.
- `src/lib/widgets/chessboard_controller.dart` -- `ChangeNotifier` owning `Position` state. Methods: `setPosition(fen)`, `playMove(move)`, `resetToInitial()`. Exposes `fen`, `sideToMove`, `isCheck`, `validMoves`, `lastMove`.
- `src/lib/screens/home_screen.dart` -- Existing screen showing current UI patterns: `StatefulWidget` receiving `AppDatabase`, creating repositories inline, loading data in `initState`. (Note: the state-management spec mandates Riverpod, but current code hasn't adopted it yet.)
- `src/lib/main.dart` -- App entry point. Creates `AppDatabase.defaults()`, passes to `HomeScreen`. Uses `MaterialApp` with Material 3 theme (indigo seed color).
- `src/lib/services/chess_utils.dart` -- `sanToMove(Position, String)` utility. Used by drill screen to convert board moves to SAN; may be useful for browser board sync.
- `src/lib/services/drill_engine.dart` -- Reference for service-layer patterns: pure Dart, no DB access, receives pre-loaded data. Shows how `RepertoireTreeCache` is consumed.

### Source files (to be created)

- `src/lib/screens/repertoire_browser_screen.dart` -- The main browser screen widget.
- `src/lib/widgets/move_tree_widget.dart` -- The tree view widget for displaying the move tree.

### Test files

- `src/test/widgets/chessboard_controller_test.dart` -- Existing test showing test conventions.
- `src/test/widgets/chessboard_widget_test.dart` -- Existing widget test showing widget test patterns.
- `src/test/services/drill_engine_test.dart` -- Existing service test showing how `RepertoireTreeCache` is constructed in tests with hand-built `RepertoireMove` objects.

## Architecture

The repertoire browser is a read-only navigation interface for the move tree. It sits in the UI layer and depends on the repository layer for data loading and `RepertoireTreeCache` for in-memory tree operations.

### Data flow

```
Repository Layer                    Browser Controller              UI Widgets
----------------                    ------------------              ----------
getMovesForRepertoire() ------>  RepertoireTreeCache  <---------  MoveTreeWidget
                                 (eager, one query)                (expand/collapse)
getCardsForSubtree()   ------>  due-count map          <---------  Node badges

                                 selected node state   <---------  ChessboardWidget
                                 (FEN, line path)                  (board preview)
```

### Key components

1. **RepertoireTreeCache** (existing) -- The browser's primary data source. Built once on screen entry from `getMovesForRepertoire()`. Provides `getRootMoves()`, `getChildren(moveId)`, `getLine(moveId)`, `isLeaf(moveId)`. All tree navigation is O(1) lookup or O(depth) path walk against this cache.

2. **Browser controller** (to be created) -- A Riverpod notifier (or, following current codebase patterns, initially a simpler state holder) that owns:
   - The `RepertoireTreeCache`
   - The currently selected node (nullable `RepertoireMove`)
   - The expand/collapse state (set of expanded node IDs)
   - Board orientation (Side)
   - Due-card counts per subtree (map of moveId to count)

3. **MoveTreeWidget** (to be created) -- A widget that renders the move tree as an expandable list. Each node shows SAN notation with move number, label (if present), branch indicator, and due-count badge. Nodes with labels are visually prominent. Tapping selects; tapping the branch indicator expands/collapses.

4. **RepertoireBrowserScreen** (to be created) -- The screen widget that composes the tree widget, chessboard preview, action bar, and breadcrumb/header. Layout: stacked portrait (board on top, tree below) as the default.

5. **ChessboardWidget** (existing, CT-1.1) -- Used in read-only mode (`playerSide: PlayerSide.none`) to show the position at the selected node. The controller's `setPosition(fen)` updates the board when the user selects a different node.

### Key constraints

- **Eager loading.** The full tree is loaded into `RepertoireTreeCache` on entry. No lazy child loading needed for v1 (typical repertoires are tens to low hundreds of nodes).
- **Display names are always derived.** The aggregate display name (e.g., "Sicilian -- Najdorf") is computed by walking the root-to-node path and concatenating labels. Never stored.
- **Board is read-only in browse mode.** The user cannot play moves on the board. Entering edit mode (CT-2.2) or adding a line requires an explicit action.
- **No Drift streams for the tree.** The tree cache is static during browsing. It is rebuilt when returning from line-entry mode.
- **Due-card counts** are computed once on load via `getCardsForSubtree` for each labeled node (or all nodes), then cached in the controller.
- **Actions from browser** (focus mode, add line, delete leaf, edit label) are entry points only in CT-2.1. The actual implementations are in CT-2.2 (edit mode), CT-2.3 (labeling), CT-2.4 (deletion), and CT-4 (focus mode). CT-2.1 provides the navigation and UI hooks; action handlers will be wired in their respective tasks.
