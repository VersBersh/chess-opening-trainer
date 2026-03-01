# CT-2.4 Context

## Relevant Files

### Specs

- `features/line-management.md` -- Primary spec for deletion behavior. Defines: leaf deletion removes its review card; orphan handling when a parent becomes childless after deletion ("Keep shorter line" creates a new card, "Remove move" deletes recursively); "Delete branch" removes a node and all descendants with a confirmation dialog showing affected line/card count; orphan handling applies after subtree deletion to the deleted node's parent.
- `architecture/repository.md` -- Defines `RepertoireRepository` (deleteMove, countLeavesInSubtree) and `ReviewRepository` (deleteCard, getCardForLeaf, getCardsForSubtree). Documents the ON DELETE CASCADE behavior on `parent_move_id` and `leaf_move_id` foreign keys, which means deleting a move cascades to its descendants and their review cards automatically.
- `features/repertoire-browser.md` -- Defines the "Delete a Leaf" action available when the selected node is a leaf. States that deletion follows rules in line-management.md and requires confirmation.
- `architecture/models.md` -- Defines `RepertoireMove` (id, repertoire_id, parent_move_id, fen, san, label, sort_order), `ReviewCard` (id, repertoire_id, leaf_move_id, ease_factor, interval_days, repetitions, next_review_date, last_quality), and `RepertoireTreeCache` (moves_by_id, children_by_parent_id, moves_by_fen, root_moves with getSubtree, isLeaf, getChildren, getLine methods).

### Source files (to modify)

- `src/lib/screens/repertoire_browser_screen.dart` -- The main browser screen. Currently has a stub Delete button (line ~689) that is enabled only when the selected node is a leaf, with an empty `onPressed`. This is where the deletion UI flow (confirmation dialogs, orphan prompt, "Delete branch" action) will be wired. Also contains `_loadData()` which rebuilds the tree cache after mutations, a pattern used by the confirm-line flow.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface. Currently has `deleteMove(int id)`, `countLeavesInSubtree(int moveId)`, `getOrphanedLeaves(int repertoireId)`, `pruneOrphans(int repertoireId)`, `getChildMoves(int parentMoveId)`, `isLeafMove(int moveId)`. May need a new `deleteSubtree(int moveId)` method for atomic subtree deletion, though `deleteMove` already cascades via the FK constraint.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite/Drift implementation. `deleteMove(int id)` does a simple DELETE by ID; due to `ON DELETE CASCADE` on `parent_move_id`, this cascades to all descendants. Review cards are also cascade-deleted via `leaf_move_id`. `countLeavesInSubtree` uses a recursive CTE. `getOrphanedLeaves` finds leaf moves with no review card (useful for detecting orphans after deletion). `pruneOrphans` iteratively removes childless, card-less moves.
- `src/lib/repositories/review_repository.dart` -- Abstract interface. Has `deleteCard(int id)`, `getCardForLeaf(int leafMoveId)`, `getCardsForSubtree(int moveId, {bool dueOnly, DateTime? asOf})`, `saveReview(ReviewCardsCompanion card)`. The `getCardsForSubtree` method counts cards under a subtree (used for the confirmation dialog). `getCardForLeaf` retrieves a card by its leaf move (used for leaf deletion). `saveReview` creates a new card (used for "Keep shorter line" orphan handling).

### Source files (read-only, for context)

- `src/lib/repositories/local/database.dart` -- Drift schema. Key detail: `RepertoireMoves.parentMoveId` has `onDelete: KeyAction.cascade`, so deleting a move automatically deletes all descendants. `ReviewCards.leafMoveId` also has `onDelete: KeyAction.cascade`, so deleting a move that is a leaf automatically deletes its review card. PRAGMA foreign_keys = ON is set in `beforeOpen`.
- `src/lib/repositories/local/local_review_repository.dart` -- Implementation of `ReviewRepository`. `getCardsForSubtree` uses a recursive CTE to collect all cards under a subtree -- used for the confirmation dialog's card count. `getCardForLeaf` does a simple select by `leafMoveId`. `saveReview` handles both insert (new card) and update (existing card) via `card.id.present` check.
- `src/lib/models/repertoire.dart` -- `RepertoireTreeCache` with `getSubtree(moveId)` (returns the move and all descendants), `isLeaf(moveId)`, `getChildren(moveId)`, `getLine(moveId)` (root-to-move path). These are used for in-memory tree queries during the deletion UI flow (e.g., checking if a parent is now childless after a leaf deletion, counting affected nodes for confirmation).
- `src/lib/widgets/move_tree_widget.dart` -- The tree view widget. Stateless; receives all data from the parent screen. No changes needed here -- the tree re-renders automatically when the tree cache is rebuilt after deletion.
- `src/test/screens/repertoire_browser_screen_test.dart` -- Existing test file with helper functions `createTestDatabase()`, `seedRepertoire()` (seeds a repertoire with lines and optional labels), and `buildTestApp()`. Uses in-memory Drift database. This is where deletion tests will be added.

## Architecture

The deletion subsystem spans the UI layer (browser screen), the repository layer (move and card CRUD), and the in-memory tree cache.

### Data flow for deletion

```
User Action                Browser Screen              Repository Layer         Database (SQLite)
-----------                ---------------              ----------------         -----------------
Tap "Delete" on leaf  -->  Show confirmation dialog
User confirms         -->  deleteMove(leafId)      -->  DELETE FROM             CASCADE deletes
                                                        repertoire_moves         descendants + cards
                      -->  Check parent childless?
                           (via getChildMoves or
                            tree cache)
Parent childless      -->  Show orphan prompt
"Keep shorter line"   -->  saveReview(new card     -->  INSERT INTO
                            for parent)                 review_cards
"Remove move"         -->  deleteMove(parentId)    -->  DELETE cascades
                           Recurse up if grandparent
                           also becomes childless
                      -->  _loadData() rebuilds
                           tree cache
```

### Key components

1. **ON DELETE CASCADE** -- The `parent_move_id` FK cascades, so `deleteMove(id)` automatically removes all descendants. The `leaf_move_id` FK on `review_cards` also cascades, so cards for deleted leaves are automatically removed. This means a single `deleteMove` call handles both subtree deletion and card cleanup at the database level.

2. **countLeavesInSubtree(moveId)** -- Recursive CTE that counts leaf nodes under a move. Used by the confirmation dialog to show "This will delete N lines."

3. **getCardsForSubtree(moveId)** -- Recursive CTE joined with `review_cards`. Returns all cards under a subtree. Used by the confirmation dialog to show "and N review cards."

4. **getChildMoves(parentMoveId)** / **isLeafMove(moveId)** -- Used after deletion to check whether the parent has become childless (orphan detection).

5. **RepertoireTreeCache.getSubtree(moveId)** -- In-memory subtree traversal. Could be used for pre-deletion counts instead of DB queries, but the DB methods are authoritative.

6. **_loadData()** -- Existing pattern in the browser screen that rebuilds the tree cache from scratch. Called after every mutation (line entry, and now deletion) to keep the UI in sync.

### Key constraints

- **Orphan handling is recursive.** After deleting a leaf, if its parent becomes childless, the user must choose "Keep shorter line" or "Remove move." If they choose "Remove move" and the grandparent also becomes childless, the prompt must repeat (or the same choice can be applied up the chain automatically).
- **Subtree deletion triggers orphan handling.** After deleting a branch, the deleted node's parent may become childless, so the orphan prompt must appear.
- **"Delete branch" is available on any node**, not just leaves. The Delete button in the current stub is only enabled for leaves. The plan must add a "Delete branch" action for non-leaf nodes (possibly via a context menu or long-press, or by changing the Delete button behavior based on whether the node is a leaf or interior).
- **Confirmation dialog must show counts.** Before subtree deletion, show the number of affected lines (leaves) and cards.
- **Cards are created only for leaves.** When a parent becomes the new leaf via "Keep shorter line," a new card with default SR values is created.
- **Root move deletion is possible.** If the user deletes a root move (no parent), no orphan handling is needed for the parent -- the move is simply removed.
