# CT-59: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Controller owning `_pendingLabels` map, `hasNewMoves`, `confirmAndPersist()`, and all confirm/label logic |
| `src/lib/screens/add_line_screen.dart` | Screen widget; wires Confirm button enable/disable via `_controller.hasNewMoves`, guards `_onConfirmLine` with `if (!_controller.hasNewMoves) return`, manages `PopScope.canPop` |
| `src/lib/services/line_entry_engine.dart` | Pure engine; `hasNewMoves` checks `_bufferedMoves.isNotEmpty`; unaware of pending labels |
| `src/lib/services/line_persistence_service.dart` | Orchestrates DB writes; `persistNewMoves()` requires non-empty `confirmData.newMoves`; no label-only persist path exists |
| `src/lib/repositories/repertoire_repository.dart` | Abstract repo; defines `updateMoveLabel(int, String?)` for single-label writes; no batch-label-only method |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Concrete repo; implements `updateMoveLabel` and `*WithLabelUpdates` transaction variants |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model used in pills list |
| `features/add-line.md` | Spec: "On confirm, any pending label changes ... are persisted along with the new moves" (step 6 of entry flow) |
| `features/line-management.md` | Spec: deferred label persistence model -- pending-labels map, persisted on Confirm |
| `src/test/controllers/add_line_controller_test.dart` | Unit tests for the controller |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the screen |

## Architecture

The Add Line subsystem follows a controller/screen split:

- **`LineEntryEngine`** is a pure model that tracks three move lists: `existingPath` (root-to-start), `followedMoves` (existing moves the user re-played), and `bufferedMoves` (new unsaved moves). Its `hasNewMoves` property returns `bufferedMoves.isNotEmpty`.

- **`AddLineController`** wraps the engine and adds label tracking. It maintains a `_pendingLabels` map (`Map<int, String?>`) keyed by pill index for label edits on saved moves. Buffered-pill labels live directly on `BufferedMove.label`. On confirm, `confirmAndPersist()` collects `_pendingLabels` entries into `PendingLabelUpdate` objects and passes them alongside the new moves to `LinePersistenceService.persistNewMoves()`.

- **`AddLineScreen`** enables the Confirm button with `_controller.hasNewMoves ? _onConfirmLine : null`. The `_onConfirmLine` handler also early-returns if `!_controller.hasNewMoves`. The `PopScope.canPop` similarly uses `!_controller.hasNewMoves` to guard navigation.

### The Bug

When a user follows an existing line (no buffered moves) and edits labels on saved pills, `_pendingLabels` accumulates entries but `hasNewMoves` remains `false`. As a result:

1. The Confirm button stays disabled (null `onPressed`).
2. `_onConfirmLine` early-returns even if somehow invoked.
3. `confirmAndPersist()` returns `ConfirmNoNewMoves` early.
4. Navigating away is allowed without the discard dialog (since `canPop` is `true`).
5. Pending labels are silently discarded.

### Key Constraints

- **No immediate writes:** The spec requires deferred persistence -- labels must be saved on Confirm, not on each keystroke.
- **Existing transaction paths assume new moves:** `LinePersistenceService.persistNewMoves()` throws if `confirmData.newMoves` is empty. The `*WithLabelUpdates` repo methods wrap label updates inside the same transaction as move inserts.
- **Label-only persist needs a new path:** There is no `persistLabelsOnly` method on `LinePersistenceService` or batch-update method on `RepertoireRepository`.
