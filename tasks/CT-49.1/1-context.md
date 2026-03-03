# CT-49.1: Deferred Label Persistence -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Primary target. Owns `updateLabel()`, `updateBufferedLabel()`, `_buildPillsList()`, `confirmAndPersist()`, and the `AddLineState`. Currently calls `_repertoireRepo.updateMoveLabel()` directly inside `updateLabel()`, triggering a DB write + full engine rebuild. |
| `src/lib/screens/add_line_screen.dart` | UI layer. Hosts the `InlineLabelEditor` for saved and unsaved pills. The `onSave` callback for saved pills calls `_controller.updateLabel()` and then resets the board position. For unsaved pills, calls `_controller.updateBufferedLabel()`. |
| `src/lib/services/line_persistence_service.dart` | Persistence layer. Accepts `ConfirmData` and writes moves via `_persistExtension()` or `_persistBranch()`. Currently handles buffered-move labels through `BufferedMove.label` on the `RepertoireMovesCompanion`, but has no mechanism for updating labels on already-saved (followed) moves. |
| `src/lib/services/line_entry_engine.dart` | Pure business logic for line entry. Manages `_existingPath`, `_followedMoves`, and `_bufferedMoves`. Produces `ConfirmData` with `newMoves` (buffered only). Provides `setBufferedLabel()`, `reapplyBufferedLabels()`, and `getCurrentDisplayName()`. |
| `src/lib/models/repertoire.dart` | Contains `RepertoireTreeCache` (in-memory indexed tree), `LabelImpactEntry`. Provides `getAggregateDisplayName()`, `previewAggregateDisplayName()`, `getDescendantLabelImpact()`, `findLabelConflicts()`. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract repository interface. Defines `updateMoveLabel()` which the controller currently calls during label editing. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Concrete Drift-based repository. Implements `updateMoveLabel()`, `extendLine()`, `saveBranch()`. The `extendLine` and `saveBranch` methods run inside DB transactions. |
| `src/lib/repositories/local/database.dart` | Drift schema. `RepertoireMoves` table has a nullable `label` column. |
| `src/lib/widgets/inline_label_editor.dart` | Shared inline editor widget. Calls `onSave` callback when editing completes. Agnostic to whether persistence is immediate or deferred. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` data class with `san`, `isSaved`, and `label` fields. |
| `src/lib/widgets/repertoire_dialogs.dart` | Contains `LabelChangeCancelledException` used when user cancels from impact warning. |
| `src/test/controllers/add_line_controller_test.dart` | Tests for the controller, including `updateLabel`, `updateBufferedLabel`, and buffered-label preservation. Tests currently verify DB persistence on `updateLabel`. |
| `src/test/services/line_persistence_service_test.dart` | Tests for `LinePersistenceService.persistNewMoves()`. |
| `src/test/services/line_entry_engine_test.dart` | Tests for `LineEntryEngine`. |
| `features/add-line.md` | Feature spec. Documents deferred label persistence: "Label edits are held in local state (a pending-labels map), not written to the database immediately." |
| `features/line-management.md` | Feature spec. Documents deferred label persistence subsection with the same pattern. |

## Architecture

### Subsystem: Add Line Entry Flow

The Add Line screen implements a builder pattern for constructing opening lines. The user plays moves on a chessboard, each move is processed by the `LineEntryEngine`, and the result is reflected in move pills displayed below the board. The flow involves three layers:

1. **LineEntryEngine** (pure logic, no DB) -- Tracks three move lists:
   - `existingPath`: moves from root to the starting position (already in DB, read-only context).
   - `followedMoves`: existing DB moves the user followed during this session (already saved).
   - `bufferedMoves`: new moves not yet in the DB (pending persistence).

   The engine produces `ConfirmData` containing only `bufferedMoves` (as `newMoves`) for the persistence layer.

2. **AddLineController** (ChangeNotifier) -- Owns the engine, `RepertoireTreeCache`, and `AddLineState`. Translates user actions into engine calls and state updates. Builds the `MovePillData` list from all three move lists. Currently has two label-edit methods:
   - `updateLabel()` -- for saved pills: writes to DB immediately via `_repertoireRepo.updateMoveLabel()`, then reloads the entire tree cache and replays buffered moves. This is the method that must be changed.
   - `updateBufferedLabel()` -- for unsaved pills: mutates `BufferedMove.label` in memory. Already deferred. No changes needed.

3. **LinePersistenceService** -- Receives `ConfirmData` and persists new moves via `extendLine()` or `saveBranch()`. Both paths already carry `BufferedMove.label` through to the `RepertoireMovesCompanion`. This service has no concept of label updates on existing (already-saved) moves.

### Key Constraints

- **Builder pattern**: Everything is assembled in memory, then committed atomically on Confirm. Label editing on saved pills currently violates this by writing to DB immediately.
- **No full-tree reload during entry**: The current `updateLabel()` calls `loadData()`-style logic (reload all moves, rebuild cache, replay buffered moves). This is expensive and unnecessary for a local-only label change.
- **ConfirmData only carries buffered moves**: The `LinePersistenceService` currently has no way to apply label updates to existing moves. A new parameter or data structure is needed.
- **Aggregate display name**: Currently computed from the tree cache only (via `engine.getCurrentDisplayName()`). Pending labels on followed moves are not reflected in the display name until after DB write + reload. The new flow must overlay pending labels into this computation.
- **Labels on both saved and unsaved pills**: Saved pills (existingPath + followedMoves) use `RepertoireMove.label` from the DB. Unsaved pills (bufferedMoves) use `BufferedMove.label`. The pending-labels map will override labels for saved pills without modifying the DB.
- **Abandoning discards everything**: Navigating away already discards buffered moves. Pending labels stored in the controller will be discarded along with the controller instance.
