# CT-2.3 Context

## Relevant Files

### Specs

- `features/line-management.md` -- Defines the labeling system: labels are optional short name segments on any node, aggregate display name is computed by walking root-to-leaf and joining labels with " -- ", aggregate name preview during entry, label impact warning (deferred to post-v0), transposition conflict warning (deferred to post-v0), labels don't create cards, not all lines need labels.
- `features/repertoire-browser.md` -- Defines the "Edit Label" action from the browser: opens an inline editor or dialog to set/change/clear a node's label. Shows aggregate display name in a header/breadcrumb when a node is selected. Labeled nodes are visually prominent in the tree (bold text, distinct color).
- `taxonomy.md` -- Formal definitions: Label is an optional short name segment on a move node; Display Name is the full computed name from aggregated labels, never stored; Variation is an informal term for a labeled subtree.
- `architecture/models.md` -- Defines `RepertoireMove.label` (optional field), `RepertoireTreeCache` with `getLine(moveId)` for path reconstruction and `getMovesAtPosition(fen)` for FEN-based lookups. Display name is "always derived from the tree."
- `architecture/repository.md` -- Defines the `RepertoireRepository` interface and the `repertoire_moves` table schema including the `label TEXT` nullable column and the `idx_moves_fen` index on `(repertoire_id, fen)`.

### Source files (existing, to be modified)

- `src/lib/screens/repertoire_browser_screen.dart` -- The browser screen. Contains a stub "Label" button in the browse-mode action bar (`onPressed: null, // Stub -- wired in CT-2.3`). Already displays the aggregate display name in a header when a node is selected (via `cache.getAggregateDisplayName(selectedId)`). Also shows the display name during edit mode via `lineEntryEngine.getCurrentDisplayName()`. The label button needs to be wired to open a label editor dialog.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract repository interface. Currently has `saveMove` (inserts a new move) but no `updateMoveLabel` method. Needs a new method to update just the label field on an existing move.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite/Drift implementation. Needs the implementation of the new `updateMoveLabel` method using Drift's `update` + `write` pattern (already demonstrated in `local_review_repository.dart` for `saveReview`).
- `src/lib/models/repertoire.dart` -- Contains `RepertoireTreeCache` with `getAggregateDisplayName(moveId)` (walks root-to-move path, filters for labels, joins with " -- "). Also has `getMovesAtPosition(fen)` for transposition lookups and `getSubtree(moveId)` for descendant traversal. The cache holds immutable `RepertoireMove` instances from the DB; after a label update, the cache must be rebuilt or surgically updated.
- `src/lib/repositories/local/database.dart` -- Drift schema. `RepertoireMoves` table has a `label` column: `TextColumn get label => text().nullable()()`. The generated `RepertoireMovesCompanion` supports `label: Value<String?>` for updates.
- `src/lib/widgets/move_tree_widget.dart` -- Tree view widget. `_MoveTreeNodeTile` already displays labels: if `node.move.label != null`, it renders the label text in bold primary color next to the move notation. No changes needed for display -- the tree will automatically show labels when they exist on moves.

### Source files (existing, reference only)

- `src/lib/repositories/local/database.g.dart` -- Drift-generated code. Shows `RepertoireMove` data class with `label` field and `RepertoireMovesCompanion` with `Value<String?> label` for partial updates.
- `src/lib/repositories/local/local_review_repository.dart` -- Shows the update pattern for Drift: `_db.update(_db.reviewCards)..where((c) => c.id.equals(id)).write(companion)`. The same pattern applies for updating a move's label.
- `src/lib/services/line_entry_engine.dart` -- Contains `getCurrentDisplayName()` which delegates to `treeCache.getAggregateDisplayName()`. Relevant because labels can also be accessed during edit mode, though editing labels during line entry is not the primary flow.
- `src/lib/repositories/review_repository.dart` -- Abstract review repository. Not directly modified, but `getCardsForSubtree` may be relevant if label impact warnings need to show affected card counts.

### Test files (reference for patterns)

- `src/test/screens/repertoire_browser_screen_test.dart` -- Widget tests for the browser. Shows `seedRepertoire(db, lines:, labelsOnSan:)` helper that seeds moves with labels. Shows `createTestDatabase()` and `buildTestApp(db, repId)` patterns. This file will be extended with label-editing tests.
- `src/test/models/repertoire_tree_cache_test.dart` -- Tests for `RepertoireTreeCache`, including `getAggregateDisplayName`. Reference for testing cache behavior.

## Architecture

### Subsystem overview

Position labeling is an organizational layer on top of the repertoire move tree. It allows users to attach short name segments to any move node, which the system aggregates into display names for lines. The labeling system touches three layers:

1. **Data layer** -- The `label` nullable text column on `repertoire_moves` in the SQLite database. Already exists in the schema. Needs a repository method to update it.

2. **Cache layer** -- The `RepertoireTreeCache` holds in-memory copies of all `RepertoireMove` objects. It provides `getAggregateDisplayName(moveId)` (walks root-to-node, collects labels, joins with " -- ") and `getMovesAtPosition(fen)` (returns all moves reaching a given FEN, useful for transposition conflict detection). After a label change, the cache must be refreshed because it holds immutable `RepertoireMove` instances. The simplest correct approach is a full rebuild via `_loadData()`, matching the pattern used after line entry confirmation.

3. **UI layer** -- The browser screen already displays labels in two places: (a) the aggregate display name header when a node is selected, and (b) bold label text next to each move in the tree widget. The missing piece is the label editor: a dialog or inline editor accessible via the "Label" button in the action bar, allowing the user to set, change, or clear a label on the selected node.

### Data flow for labeling

```
User taps "Label" button (selected node required)
        |
        v
Label editor dialog opens
  - Pre-filled with existing label (or empty)
  - Shows aggregate display name preview (current path labels + new label)
  - [post-v0] Shows label impact warning if node has labeled descendants
  - [post-v0] Shows transposition conflict warning if same FEN has different labels
        |
        v (on save)
RepertoireRepository.updateMoveLabel(moveId, newLabel)
        |
        v
Rebuild RepertoireTreeCache (full reload via _loadData)
        |
        v
UI updates: tree shows new label, header shows updated aggregate name
```

### Key constraints

- **Labels don't create cards.** Labeling or unlabeling a node has no effect on the `review_cards` table or the tree structure. It is a metadata-only update.
- **Display name is always derived.** The full display name is never stored. It is computed by `RepertoireTreeCache.getAggregateDisplayName(moveId)` which walks the root-to-node path and joins all labels with " -- ".
- **Label impact warning is deferred to post-v0.** The spec explicitly marks this as deferred: "Requires subtree traversal and before/after display name computation." For v0, labels work fully without this warning.
- **Transposition conflict warning is deferred to post-v0.** The spec explicitly marks this as deferred: "Requires FEN-based lookups across the move tree." For v0, users can label positions freely without warnings about conflicting labels on transpositions.
- **Cache rebuild after label change.** Since `RepertoireMove` instances in the cache are immutable (Drift `DataClass`), updating a label in the DB requires rebuilding the cache. The `_loadData()` method already handles this and is the established pattern (used after line entry confirmation).
- **Label is accessible from browse mode only (v0).** The spec says "accessible from browse or edit mode" but during edit mode the user is focused on move entry, not labeling. For v0, the label button is in the browse-mode action bar (already stubbed). Edit-mode labeling can be added later if needed.
- **Any node can be labeled.** The label button should be enabled whenever a node is selected, regardless of whether it is a leaf, branch point, root move, or interior node.
