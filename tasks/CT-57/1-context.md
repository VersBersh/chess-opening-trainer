# CT-57 Context

## Relevant Files

| File | Role |
|------|------|
| `features/add-line.md` | Spec for the Add Line screen. Contains the Transposition Detection section (added by CT-56) that must be updated with a Reroute subsection. |
| `features/line-management.md` | Spec for line entry mechanics. Must be updated with a Rerouting subsection. |
| `architecture/models.md` | Defines `RepertoireTreeCache` (in-memory indexed tree view), `RepertoireMove`, and `ReviewCard` data models. |
| `architecture/repository.md` | Defines `RepertoireRepository` interface. Must be updated with the new `reparentChildren` method. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` implementation. Contains `movesByPositionKey`, `getLine()`, `getAggregateDisplayName()`, `getPathDescription()`, `countDescendantLeaves()`, `getChildren()`, `isLeaf()`. Core data source for tree structure and transposition lookups. |
| `src/lib/services/line_entry_engine.dart` | Pure business-logic service for line entry. Defines `TranspositionMatch` (with `moveId`, `aggregateDisplayName`, `pathDescription`, `isSameOpening`), `BufferedMove`, `ConfirmData`. Contains `findTranspositions()` method used by the controller. |
| `src/lib/services/line_persistence_service.dart` | Service that persists new moves from line entry. Has `persistNewMoves()` which delegates to `_persistExtension` or `_persistBranch`. The reroute logic needs a similar persistence path for buffered moves before the convergence point. |
| `src/lib/services/deletion_service.dart` | Handles delete-leaf, delete-branch, and orphan handling. Contains `handleOrphans()` pattern (walk up from childless node, optionally creating cards or deleting). The reroute pruning logic is a simplified version of this. |
| `src/lib/controllers/add_line_controller.dart` | Controller for the Add Line screen. Owns `LineEntryEngine`, `RepertoireTreeCache`, `_pendingLabels`, and `AddLineState`. Contains `_computeTranspositions()`, `_computeActivePathSnapshot()`, `confirmAndPersist()`. The reroute action will be a new public method here. |
| `src/lib/screens/add_line_screen.dart` | UI for the Add Line screen. Contains `_buildTranspositionWarning()` which currently renders the Reroute button as disabled (`onPressed: null`). Must wire the button to a confirmation dialog and controller method. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract `RepertoireRepository` interface. Must add `reparentChildren()` and potentially `persistBufferedMoves()` methods. Also contains `PendingLabelUpdate` class. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | SQLite/Drift implementation of `RepertoireRepository`. Must implement the new repository methods using transactions. |
| `src/lib/repositories/local/database.dart` | Drift schema defining `RepertoireMoves`, `ReviewCards` tables, indexes, and sibling uniqueness constraints (`idx_moves_unique_sibling`). The uniqueness constraint is what will cause SAN conflicts during reroute. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface. Read-only for this task -- review cards are keyed by `leaf_move_id` which is not changed during reroute. |
| `src/lib/widgets/repertoire_dialogs.dart` | Shared dialog helpers (delete confirmation, orphan prompt, label impact warning). The reroute confirmation dialog follows this pattern. |
| `src/test/controllers/add_line_controller_test.dart` | Integration tests for `AddLineController` using in-memory DB via `seedRepertoire()`. New reroute tests go here. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for `AddLineScreen`. New widget tests for the reroute confirmation dialog flow go here. |
| `src/test/services/line_persistence_service_test.dart` | Unit tests for `LinePersistenceService`. |
| `src/test/services/deletion_service_test.dart` | Unit tests for `DeletionService` with `FakeRepertoireRepository` and `FakeReviewRepository`. Pattern reference for testing the reroute service. |
| `src/lib/providers.dart` | Riverpod providers for repositories. Used by the screen to instantiate the controller. |

## Architecture

### Subsystem overview

The Add Line subsystem is a three-layer stack:

1. **`LineEntryEngine`** (pure logic, no Flutter/DB) -- tracks the user's current path through the repertoire tree. Maintains three ordered lists: `_existingPath` (saved moves from root to starting node), `_followedMoves` (existing tree moves followed after start), and `_bufferedMoves` (new moves not yet in DB). Knows the `_lastExistingMoveId` and whether the user `_hasDiverged`. Has read-only access to `RepertoireTreeCache` for lookups but performs no I/O.

2. **`AddLineController`** (ChangeNotifier) -- owns the engine, tree cache, and `_pendingLabels` map. Translates user actions (board move, take-back, confirm, label edit, pill tap) into engine calls. After each action, rebuilds `AddLineState` (immutable snapshot containing pills, FEN, display name, transpositionMatches) and calls `notifyListeners()`.

3. **`AddLineScreen`** (ConsumerStatefulWidget) -- renders the UI. Listens to the controller and rebuilds on state change. Layout: AppBar > board > scrollable area (pills, transposition warning, inline editors, parity warning) > fixed bottom action bar.

### Transposition detection (CT-56, already implemented)

- `AddLineState.transpositionMatches` holds `List<TranspositionMatch>`, recomputed on every position/label change.
- Each `TranspositionMatch` contains `moveId` (the ID of the existing move that reaches the same position), `aggregateDisplayName`, `pathDescription`, and `isSameOpening`.
- The screen's `_buildTranspositionWarning()` renders each match as a row with name, path, and a Reroute button (currently disabled with `onPressed: null`) for same-opening matches.

### Persistence patterns

- **Branch persistence:** `LinePersistenceService._persistBranch()` chains new moves via `RepertoireRepository.saveBranch()` which inserts moves with parent chaining in a transaction, then creates a review card for the new leaf.
- **Extension persistence:** `LinePersistenceService._persistExtension()` uses `RepertoireRepository.extendLine()` which deletes the old leaf's card, inserts new moves chained to the old leaf, and creates a card for the new leaf.
- **Label updates:** Both `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates` apply pending label changes in the same transaction.
- **Undo:** `undoExtendLine` and `undoNewLine` delete inserted moves (CASCADE handles descendants and cards) and restore old cards.

### Tree structure and constraints

- The `repertoire_moves` table stores an adjacency list: each node has `parent_move_id` (nullable for root moves).
- Sibling uniqueness is enforced by `idx_moves_unique_sibling` (`UNIQUE ON (parent_move_id, san) WHERE parent_move_id IS NOT NULL`) and `idx_moves_unique_root` (`UNIQUE ON (repertoire_id, san) WHERE parent_move_id IS NULL`).
- `ON DELETE CASCADE` on `parent_move_id` means deleting a node automatically deletes all descendants.
- Review cards reference `leaf_move_id` with `ON DELETE CASCADE`, so deleting a move also deletes its card.

### Key constraint for reroute: SAN conflict

When re-parenting children from the old convergence node to the new convergence node, a SAN conflict occurs if the new parent already has a child with the same SAN as one being moved. The `idx_moves_unique_sibling` unique index would cause an insert/update failure. The reroute must check for this before attempting the update and block with an explanation if found.

### Pruning pattern

`DeletionService.handleOrphans()` walks up from a childless node toward the root, asking the user at each step whether to keep a shorter line or remove the move. The reroute pruning is simpler: no user prompt needed -- just delete childless nodes up to the nearest node that still has other children or a review card. This is a subset of `handleOrphans` with an automatic "remove move" choice at each step, stopping when a node has children or a card.

### Review card preservation

Review cards are keyed by `leaf_move_id`. Rerouting only changes `parent_move_id` on intermediate/convergence nodes, not leaf IDs. So existing review cards and their SR state are preserved automatically -- no card migration needed.
