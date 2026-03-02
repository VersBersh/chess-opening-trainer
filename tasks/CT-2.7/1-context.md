# CT-2.7 Context: Undo Snackbar After Line Confirm

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget that shows the undo snackbar. Currently only shows snackbar for extensions, not new lines. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller. Owns confirm flow, undo generation counter, and `undoExtension()`. Needs a new `undoNewLine()` method. |
| `src/lib/services/line_entry_engine.dart` | Pure line-entry engine. Produces `ConfirmData` with `isExtension`, `parentMoveId`, `newMoves`. No changes needed. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` -- in-memory tree index. No changes needed. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract repository interface. Needs a new `undoNewLine()` method. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | SQLite implementation. Has `undoExtendLine()` already. Needs a new `undoNewLine()` implementation. |
| `src/lib/repositories/review_repository.dart` | Abstract review repository. Has `getCardForLeaf()`, `deleteCard()`. No changes expected. |
| `src/lib/repositories/local/local_review_repository.dart` | SQLite review repository. No changes expected (card deletion cascades from move deletion). |
| `src/lib/repositories/local/database.dart` | Drift database schema. `ON DELETE CASCADE` on `parent_move_id` means deleting the first inserted move cascades to all descendants and their cards. No schema changes needed. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for AddLineScreen. Already has extension undo tests. Needs new-line undo tests. |
| `src/test/controllers/add_line_controller_test.dart` | Controller unit tests. Needs `undoNewLine` tests. |
| `src/test/repositories/local_repertoire_repository_test.dart` | Repository tests. Needs `undoNewLine` tests. |
| `features/line-management.md` | Spec defining the undo feature. The "Undo Line Extension" section describes the 8-second transient snackbar. |
| `architecture/repository.md` | Repository interface design. Documents `extendLine` and related methods. |
| `architecture/models.md` | Domain model definitions. `ReviewCard`, `RepertoireMove`, `RepertoireTreeCache`. |

## Architecture

### Subsystem Overview

The Add Line flow is a three-layer system:

1. **Screen** (`AddLineScreen`) -- Flutter widget that renders the board, move pills, and action bar. Handles user interactions and shows snackbars/dialogs. Delegates all logic to the controller.

2. **Controller** (`AddLineController`) -- ChangeNotifier that owns an `AddLineState` and a `LineEntryEngine`. Translates user actions (board moves, confirms, take-backs) into engine calls and repository writes. Manages undo via a generation counter (`_undoGeneration`) that invalidates stale snackbar callbacks.

3. **Engine** (`LineEntryEngine`) -- Pure business logic with no DB or Flutter dependencies. Tracks the distinction between existing-path moves, followed-existing moves, and buffered-new moves. Produces `ConfirmData` for persistence.

### Confirm Flow (Current)

When the user taps Confirm:
1. `AddLineScreen._onConfirmLine()` calls `_controller.confirmAndPersist()`.
2. The controller validates parity, increments `_undoGeneration`, and calls `_persistMoves()`.
3. `_persistMoves()` checks `confirmData.isExtension`:
   - **Extension path**: Calls `_repertoireRepo.extendLine()` atomically (deletes old card, inserts moves, creates new card). Captures `oldCard` before the call. Returns `ConfirmSuccess(isExtension: true, oldLeafMoveId, insertedMoveIds, oldCard)`.
   - **New line path**: Inserts moves one-by-one chaining parent IDs, then creates a card for the new leaf. Returns `ConfirmSuccess(isExtension: false, insertedMoveIds: insertedIds)`.
4. Both paths call `loadData()` to rebuild the tree cache.
5. Back in the screen, `_handleConfirmSuccess()` resets the board position, then conditionally shows an undo snackbar **only for extensions**.

### Undo Mechanism (Extension Only, Current)

- `_showExtensionUndoSnackbar()` captures the `_undoGeneration` at the time of the snackbar.
- If the user taps Undo within 8 seconds, it calls `_controller.undoExtension()` which checks the generation counter (stale snackbars are no-ops) then calls `_repertoireRepo.undoExtendLine()`.
- `undoExtendLine()` in a transaction: deletes the first inserted move (CASCADE removes descendants + new card), then re-inserts the old card.

### What's Missing

The undo snackbar is only shown for extensions. For new lines (branching from a non-leaf or from root), there is no undo. The task requires:
- A new-line undo snackbar after confirming a new line.
- Tapping undo should delete all inserted moves and their card.
- The same generation-counter pattern should prevent stale undo actions.

### Key Constraints

- **CASCADE behavior**: Deleting the first inserted move cascades to all descendants and their review cards. This makes the undo operation for new lines simpler than extensions (no old card to restore).
- **Generation counter**: The existing `_undoGeneration` pattern prevents race conditions where a user confirms a second line before tapping undo on the first snackbar.
- **Branching edge case**: When a new line branches from an existing non-leaf node, that node already has children. Undo must delete only the new branch, not the existing children. Since the first inserted move's `parent_move_id` points to the existing node, deleting the first inserted move (and its CASCADE descendants) is safe -- the existing sibling branches are untouched.
