# CT-43: Context

## Relevant Files

- **`src/lib/controllers/add_line_controller.dart`** — Business logic controller for the Add Line screen. Contains `canEditLabel` (line 598), `updateLabel()`, `getMoveAtPillIndex()`, and `_buildPillsList()`. The `canEditLabel` getter currently rejects unsaved pills via `!_state.pills[focusedIndex].isSaved` guard on line 602.

- **`src/lib/screens/add_line_screen.dart`** — The Add Line screen widget. Builds the UI, action bar (Label button wired to `canEditLabel`), inline label editor, and pill-tap handler. Two key areas filter on `isSaved`: (1) `_onPillTapped` (line 117) only opens the inline editor on re-tap for saved pills, and (2) `_buildInlineLabelEditor` (line 414) calls `getMoveAtPillIndex()` which returns `null` for buffered moves, causing the editor to bail out.

- **`src/lib/widgets/move_pills_widget.dart`** — Defines `MovePillData` (data model for pills) and renders the pill row. Has an assert on line 39: `isSaved || label == null` — enforces that only saved moves may carry labels. This assert must be relaxed to allow unsaved pills to have labels.

- **`src/lib/services/line_entry_engine.dart`** — Pure business-logic engine for line entry. Defines `BufferedMove` (fields: `san`, `fen` only — no `label` field). Also contains `_bufferedMoves` list and `getConfirmData()` which builds `ConfirmData` from buffered moves.

- **`src/lib/services/line_persistence_service.dart`** — Handles persistence of new moves. Builds `RepertoireMovesCompanion` from `BufferedMove` data. Currently does not set the `label` field on companions. Must be updated to include labels when buffered moves carry them.

- **`src/lib/widgets/inline_label_editor.dart`** — Shared inline label editor widget. Requires `moveId` (int), `currentLabel`, `descendantLeafCount`, and `previewDisplayName` callback. Currently assumes a saved `RepertoireMove` backs the edited pill. Must be adapted (or a parallel path created) to work with unsaved buffered moves that have no `moveId` or tree-cache presence.

- **`src/lib/models/repertoire.dart`** — Defines `RepertoireTreeCache` and `LabelImpactEntry`. The cache provides `countDescendantLeaves()`, `previewAggregateDisplayName()`, `getDescendantLabelImpact()`, and `findLabelConflicts()` — all of which require a saved move ID. Unsaved moves are not in the cache.

- **`src/lib/repositories/local/database.g.dart`** — Generated Drift database code. `RepertoireMovesCompanion.insert()` accepts an optional `label` parameter (`Value<String?>`), so labels can be included at insert time.

- **`features/add-line.md`** — Feature spec. Lines 50-51 state: "The Label button is enabled whenever any pill is focused, regardless of board orientation or save state."

- **`src/test/controllers/add_line_controller_test.dart`** — Controller tests. Contains tests for `canEditLabel` and `updateLabel` with buffered moves. Line 1015 asserts `canEditLabel` is `false` when an unsaved pill is focused — this test must be updated to expect `true`.

- **`src/test/screens/add_line_screen_test.dart`** — Screen-level widget tests for the Add Line screen. Tests label button enablement and double-tap behavior for saved pills. Will need new tests for unsaved pill label editing.

## Architecture

### Subsystem Overview

The Add Line screen lets users build opening lines by playing moves on a chessboard. It is structured as a controller-view pair:

1. **`AddLineController`** (ChangeNotifier) owns all business logic and state. It wraps a `LineEntryEngine` that tracks three categories of moves:
   - **`existingPath`**: saved moves from root to the starting node (read-only context).
   - **`followedMoves`**: saved moves the user replayed by making moves that match existing tree children.
   - **`bufferedMoves`**: new moves not yet in the DB.

2. **`AddLineScreen`** (ConsumerStatefulWidget) renders the board, pills, inline label editor, and action bar. It delegates all state mutations to the controller and rebuilds on `notifyListeners()`.

3. **`MovePillData`** is a display-only data class that decouples the widget layer from `RepertoireMove` and `BufferedMove`. It carries `san`, `isSaved`, and an optional `label`.

### Label Editing Flow (current, saved pills only)

1. User taps a saved pill to focus it. Re-tapping the same focused saved pill opens the inline label editor.
2. The Label button in the action bar is also wired to `canEditLabel`, which checks `isSaved`.
3. `_buildInlineLabelEditor()` calls `getMoveAtPillIndex()`, which returns a `RepertoireMove` for saved pills (null for buffered). The `InlineLabelEditor` widget requires `moveId`, `descendantLeafCount`, and `previewDisplayName` — all derived from the `RepertoireTreeCache`.
4. On save, `updateLabel()` calls `_repertoireRepo.updateMoveLabel(moveId, newLabel)` — a DB update keyed on the move's ID.
5. The engine is rebuilt, buffered moves are replayed, and pills are regenerated.

### Key Constraints

- **`BufferedMove` has no `label` field.** Labels on unsaved moves must be stored somewhere in memory until confirm.
- **`InlineLabelEditor` requires a `moveId` (int).** Unsaved moves have no DB ID. The editor (or its usage) must be adapted.
- **`MovePillData` asserts `isSaved || label == null`.** This assertion blocks unsaved pills from carrying labels.
- **`LinePersistenceService` does not pass labels to `RepertoireMovesCompanion`.** Labels on buffered moves must be propagated through `ConfirmData` to the persistence layer.
- **Tree-cache operations (`countDescendantLeaves`, `previewAggregateDisplayName`, `findLabelConflicts`, `getDescendantLabelImpact`) are meaningless for unsaved moves.** The inline label editor for unsaved pills should skip or simplify these features (e.g., descendant count = 0, no conflict check, simple preview).
