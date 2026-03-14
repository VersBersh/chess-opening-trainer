# CT-57 Implementation Plan

## Goal

Add a Reroute button to the transposition warning that re-parents an existing line's continuation under the current path, allowing the user to fix move-order mistakes without deleting and re-entering long lines.

## Steps

### Step 1: Add `rerouteLine` to `RepertoireRepository`

**Files:** `src/lib/repositories/repertoire_repository.dart`, `src/lib/repositories/local/local_repertoire_repository.dart`

Add one new method to the abstract `RepertoireRepository` interface:

```dart
/// Atomic reroute operation:
/// 1. Insert [newMoves] as a chain starting from [anchorMoveId] (or as root
///    moves if null), creating the new path to the convergence point.
/// 2. Re-parent all children of [oldConvergenceId] under the last inserted
///    move (the new convergence node).
/// 3. Prune the orphaned old path: walk up from [oldConvergenceId] toward
///    the root, deleting each childless node that has no review card, stopping
///    at the first node that still has children or a review card.
/// 4. Apply any pending label updates.
/// Returns the list of inserted move IDs.
Future<List<int>> rerouteLine({
  required int? anchorMoveId,
  required List<RepertoireMovesCompanion> newMoves,
  required int oldConvergenceId,
  required List<PendingLabelUpdate> labelUpdates,
});
```

**Note:** `findReparentConflicts` is NOT added to the repository. The SAN conflict pre-check is done in-memory via `RepertoireTreeCache.getChildren()` in the controller (Step 3). The DB unique index (`idx_moves_unique_sibling`) serves as the hard safety net.

**Implementation in `LocalRepertoireRepository`:**

`rerouteLine`:
1. Open a transaction.
2. Apply pending label updates (same pattern as `extendLineWithLabelUpdates`).
3. Insert new moves in a chain from `anchorMoveId`, same pattern as `saveBranch`. Track inserted IDs. The last inserted ID is the new convergence node.
4. Read children of `oldConvergenceId`.
5. For each child, `UPDATE repertoire_moves SET parent_move_id = <newConvergenceId> WHERE id = <child.id>`.
6. Prune orphaned old path: starting from `oldConvergenceId`, walk up:
   - Query children of the current node. If any remain, stop.
   - Query whether a review card exists for the current node. If so, stop.
   - Otherwise, read `parent_move_id`, delete the current node, continue to the parent.
7. Return inserted IDs.

The re-parent UPDATE is a simple `parent_move_id` change. The `idx_moves_unique_sibling` constraint protects against SAN conflicts at the DB level; the controller pre-checks in-memory to provide a user-friendly error.

If `newMoves` is empty (the convergence node already exists in the tree), skip the insert step and use `anchorMoveId` as the new convergence ID directly.

**Dependencies:** None.

### Step 1b: Update all test fakes/spies that implement `RepertoireRepository`

**Files:**
- `src/test/services/pgn_importer_test.dart` (`SpyRepertoireRepository`)
- `src/test/services/deletion_service_test.dart` (`FakeRepertoireRepository`)
- `src/test/screens/home_screen_test.dart` (`FakeRepertoireRepository`)
- `src/test/screens/drill_screen_test.dart` (`FakeRepertoireRepository`)
- `src/test/screens/drill_filter_test.dart` (`FakeRepertoireRepository`)

Adding `rerouteLine` to the abstract `RepertoireRepository` interface will break compilation for all classes that `implements RepertoireRepository`. Each fake/spy must get a stub for the new method:

- **`SpyRepertoireRepository`** (pgn_importer_test.dart): delegates to the real `LocalRepertoireRepository`, so add `@override Future<List<int>> rerouteLine(...) => _delegate.rerouteLine(...);`.
- **All `FakeRepertoireRepository` classes** (deletion_service_test.dart, home_screen_test.dart, drill_screen_test.dart, drill_filter_test.dart): these fakes are minimal and only implement methods their tests exercise. Add a `throw UnimplementedError()` stub for `rerouteLine`.

**Dependencies:** Step 1.

### Step 2: Add `reroute` method to `LinePersistenceService`

**File:** `src/lib/services/line_persistence_service.dart`

Add a `reroute` method to `LinePersistenceService` that orchestrates the reroute operation:

```dart
/// Result of a reroute operation.
class RerouteResult {
  final List<int> insertedMoveIds;
  final int newConvergenceId;
  const RerouteResult({
    required this.insertedMoveIds,
    required this.newConvergenceId,
  });
}

Future<RerouteResult> reroute({
  required int? anchorMoveId,
  required List<BufferedMove> movesToPersist,
  required int oldConvergenceId,
  required int repertoireId,
  required int sortOrder,
  required List<PendingLabelUpdate> labelUpdates,
})
```

Logic:
1. Convert `movesToPersist` to `RepertoireMovesCompanion` list (same pattern as `_persistBranch`).
2. Call `_repertoireRepo.rerouteLine(...)`.
3. Return `RerouteResult` with inserted IDs and the new convergence ID (last inserted ID, or `anchorMoveId` if no moves were inserted).

**Dependencies:** Step 1.

### Step 3: Add `performReroute` method to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a new sealed result type:

```dart
sealed class RerouteResult {
  const RerouteResult();
}

class RerouteSuccess extends RerouteResult {
  const RerouteSuccess();
}

class RerouteConflict extends RerouteResult {
  final List<String> conflictingSans;
  const RerouteConflict({required this.conflictingSans});
}

class RerouteError extends RerouteResult {
  final String userMessage;
  const RerouteError({required this.userMessage});
}
```

Add a public method:

```dart
Future<RerouteResult> performReroute(TranspositionMatch match)
```

Logic:
1. Get the engine and tree cache. Guard against null.
2. **Compute the buffered moves to persist, sliced to `focusedPillIndex`.**
   The convergence point is the focused pill. The buffered moves start at index `existingPath.length + followedMoves.length`. Compute the number of buffered moves that belong to the reroute as:
   ```dart
   final focusedIndex = _state.focusedPillIndex ?? (totalPills - 1);
   final savedCount = engine.existingPath.length + engine.followedMoves.length;
   final bufferedCountToReroute = (focusedIndex + 1 - savedCount)
       .clamp(0, engine.bufferedMoves.length);
   final movesToPersist = engine.bufferedMoves.sublist(0, bufferedCountToReroute);
   ```
   This ensures that only the buffered prefix up to the focused pill is persisted. Any buffered moves after the focused pill are not part of the reroute and will be discarded when `_loadData` rebuilds the engine state.
3. **SAN conflict pre-check (in-memory, no DB call).**
   The conflict check uses `RepertoireTreeCache` directly:
   - If `movesToPersist` is non-empty, the new convergence node will be freshly created with no existing children, so no SAN conflict is possible. Skip the check.
   - If `movesToPersist` is empty (the convergence node already exists), determine the new convergence node's move ID (the move at `focusedIndex`). Get its children via `treeCache.getChildren(newConvergenceId)` and the old node's children via `treeCache.getChildren(match.moveId)`. Compute the SAN intersection -- if any SANs appear in both child lists, return `RerouteConflict` with those SANs.
4. Determine the anchor move ID. This is `engine.lastExistingMoveId` if no buffered moves precede the convergence, or the last followed move's ID.
5. Build pending label updates for saved moves (same pattern as `_persistMoves`).
6. Call `_persistenceService.reroute(...)` with the sliced `movesToPersist`, anchor, old convergence ID, etc.
7. Reload data via `_loadData(leafMoveId: ...)` to rebuild the tree cache and engine. Focus on the convergence node position.
8. Return `RerouteSuccess`.
9. Wrap in try/catch for error handling, return `RerouteError` on failure.

**Dependencies:** Step 2.

### Step 4: Add `getRerouteInfo` method to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a method to compute the information needed for the confirmation dialog:

```dart
({int continuationLineCount, String oldPathDescription, String newPathDescription, String? lineName})
  getRerouteInfo(TranspositionMatch match)
```

Logic:
1. Use `_state.treeCache!.countDescendantLeaves(match.moveId)` to get the number of continuation **lines** (leaf nodes in the subtree).
2. Use `_state.treeCache!.getPathDescription(match.moveId)` for the old path description. Compute the divergent segment of the old path and the corresponding segment of the current path for the dialog body.
3. Use `_state.treeCache!.getAggregateDisplayName(match.moveId)` for the line name (if non-empty).

This method is synchronous since it only reads from the in-memory tree cache.

**Dependencies:** None (only uses existing tree cache).

### Step 5: Wire the Reroute button in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

In `_buildTranspositionWarning`, change the Reroute button visibility and handler:

1. **Gate the button on non-leaf matches:** Only show the Reroute button when `match.isSameOpening` AND the matched node has children (i.e., there are continuations to reroute). Use `!controller.state.treeCache!.isLeaf(match.moveId)` as the guard. A leaf match means there is nothing to reroute -- the matched node has no children to re-parent, so the operation would be a no-op. The updated condition:
   ```dart
   if (match.isSameOpening && !_controller.state.treeCache!.isLeaf(match.moveId))
     TextButton(
       onPressed: () => _onReroute(match),
       child: const Text('Reroute'),
     ),
   ```

2. Add `_onReroute(TranspositionMatch match)` method:
   - Call `_controller.getRerouteInfo(match)` to get dialog content.
   - Show the reroute confirmation dialog (Step 6).
   - If the user confirms:
     - Call `await _controller.performReroute(match)`.
     - Handle the result:
       - `RerouteSuccess`: Show a brief success snackbar ("Line rerouted"). The transposition warning dismisses automatically because `_loadData` rebuilds the state and the transposition matches are recomputed.
       - `RerouteConflict`: Show an error snackbar explaining the SAN conflict (e.g., "Cannot reroute: move [SAN] already exists at the target position").
       - `RerouteError`: Show a generic error snackbar.
     - Sync the board to the controller's current FEN after reroute (same pattern as `_handleConfirmSuccess`).

**Dependencies:** Steps 3, 4.

### Step 6: Add the reroute confirmation dialog

**File:** `src/lib/widgets/repertoire_dialogs.dart`

Add a `showRerouteConfirmationDialog` function following the existing dialog patterns:

```dart
Future<bool?> showRerouteConfirmationDialog(
  BuildContext context, {
  required int continuationLineCount,
  required String oldPathDescription,
  required String newPathDescription,
  String? lineName,
})
```

Returns `true` if the user confirms, `false` or `null` if cancelled.

Dialog content:
- Title: "Reroute line?"
- Body: RichText with "Move **N** continuation line(s) from **[old path]** to the current path **[new path]**? This cannot be undone." Include the line name if provided.
- Actions: Cancel / Reroute.

The copy says "continuation line(s)" (not "continuation move(s)") because `countDescendantLeaves()` counts leaf lines, not descendant nodes. This is consistent with the existing UI in `InlineLabelEditor` which displays "This label applies to N lines" using the same counting method.

**Dependencies:** None.

### Step 7: Update spec files

**File:** `features/add-line.md`

In the Transposition Detection section, update the "Reroute" bullet point (currently says "wired in CT-57") to a full subsection:

```markdown
### Reroute

When a same-opening transposition match has continuation moves (the matched node is not a leaf), a **Reroute** button appears on that match row. Tapping it shows a confirmation dialog with details of what will change (number of continuation lines, old vs new path). On confirm:

1. Buffered moves up to the focused pill (convergence point) are persisted.
2. Children of the old convergence node are re-parented under the new convergence node.
3. The orphaned old path is pruned back to the nearest branching ancestor (or node with a review card).
4. The tree cache is rebuilt and the transposition warning dismisses.

SAN conflicts (the new convergence node already has a child with the same SAN as one being re-parented) block the reroute with an explanatory message. The reroute is atomic -- all-or-nothing within a single transaction.

Leaf matches (where the matched node has no children) do not show the Reroute button, as there is nothing to re-parent.
```

**File:** `features/line-management.md`

Add a "### Rerouting" subsection after "Transposition Detection During Entry":

```markdown
### Rerouting

When transposition detection identifies that an existing line reaches the current position via a different move order (same-opening match), the user can **reroute** the existing line's continuation to go through the current path instead. This re-parents the continuation moves without deleting them or losing their review card state. See [add-line.md](add-line.md#reroute) for the full UI flow.
```

**File:** `architecture/repository.md`

In the `RepertoireRepository` interface section, add the new method:

```dart
/// Atomic reroute: insert new path, re-parent children, prune orphans.
Future<List<int>> rerouteLine({...});
```

Note: no `findReparentConflicts` method -- the SAN conflict check is done in-memory in the controller via `RepertoireTreeCache`.

**Dependencies:** None.

### Step 8: Unit tests for `rerouteLine`

**File:** `src/test/services/line_persistence_service_test.dart` (or a new `src/test/repositories/local/local_repertoire_repository_reroute_test.dart` if the existing file is focused on `LinePersistenceService`)

Since the reroute logic is primarily in the repository layer, test it using an in-memory database (same pattern as `line_persistence_service_test.dart` which uses `seedRepertoire()`).

Test cases:

1. **Basic reroute: re-parents children and prunes old path** -- seed a tree with two branches reaching the same position. Call `rerouteLine`. Verify: children now under new parent, old path pruned, review cards preserved.

2. **Reroute with empty newMoves (convergence node already exists)** -- the new convergence node is already saved. Verify re-parent and prune work without inserting new moves.

3. **Reroute with buffered moves to persist** -- the new path has unsaved moves. Verify they are inserted as a chain and children are re-parented under the last inserted move.

4. **No SAN conflict when new parent has no children** -- verify that rerouting to a freshly created node succeeds without conflicts.

5. **SAN conflict at DB level** -- set up a scenario where the new parent already has a child with the same SAN as one being moved. Verify the DB constraint causes a failure (the controller pre-check should prevent this in practice, but the DB constraint is the safety net).

6. **Pruning stops at branching ancestor** -- the old path shares a prefix with another line. After reroute, verify only the orphaned segment is pruned, not the shared prefix.

7. **Pruning stops at node with review card** -- the old path has a node that became childless but has a review card. Verify it is not pruned.

8. **Label updates applied atomically** -- pass pending label updates to `rerouteLine`. Verify labels are updated in the same transaction.

9. **Review cards preserved after reroute** -- verify that leaf review cards (keyed by `leaf_move_id`) still exist and have unchanged SR state after the reroute.

**Dependencies:** Step 1.

### Step 9: Unit tests for `AddLineController.performReroute`

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a `group('Reroute', ...)` with test cases:

1. **Reroute succeeds and rebuilds state** -- seed a tree with a transposition, play moves to reach it, call `performReroute`. Verify `RerouteSuccess` returned, `transpositionMatches` is now empty, and the rerouted line is accessible from the new path.

2. **Reroute with SAN conflict returns RerouteConflict** -- seed a tree where the new parent already has a child with a conflicting SAN. Call `performReroute`. Verify `RerouteConflict` returned with the conflicting SANs.

3. **Reroute with buffered moves persists only prefix up to focusedPillIndex** -- play buffered moves past the convergence point, focus back on the convergence pill, then call `performReroute`. Verify only the buffered prefix up to the focused pill is persisted, and post-convergence buffered moves are discarded by the `_loadData` rebuild.

4. **Reroute preserves review cards** -- verify that after reroute, `getCardForLeaf` returns the same card for the leaf moves.

5. **State reloads correctly after reroute** -- verify pills, FEN, display name, and transposition matches are all consistent after reroute.

6. **Reroute not offered for leaf matches** -- seed a tree with a transposition where the matched node is a leaf. Verify `getRerouteInfo` returns a `continuationLineCount` of 0. (The UI gate in Step 5 prevents the button from appearing, but the controller should also handle this gracefully.)

**Dependencies:** Step 3.

### Step 10: Widget test for reroute confirmation dialog flow

**File:** `src/test/screens/add_line_screen_test.dart`

Add test cases:

1. **Reroute button is tappable for same-opening non-leaf matches** -- seed a tree with a same-opening transposition where the matched node has children, play moves to reach it. Verify the Reroute button is enabled and tappable.

2. **Reroute button is NOT shown for leaf matches** -- seed a tree with a same-opening transposition where the matched node is a leaf (no children). Verify no Reroute button appears even though `isSameOpening` is true.

3. **Tapping Reroute shows confirmation dialog** -- tap the Reroute button. Verify the confirmation dialog appears with the expected title and body content (including "continuation line(s)" wording).

4. **Cancelling the dialog leaves everything unchanged** -- tap Cancel in the dialog. Verify the transposition warning is still visible and no data changed.

5. **Confirming the dialog performs the reroute** -- tap Reroute in the dialog. Verify the transposition warning dismisses and a "Line rerouted" snackbar appears.

6. **Reroute button is not shown for cross-opening matches** -- seed a tree with a cross-opening transposition. Verify no Reroute button is visible.

7. **Update existing Reroute button test** -- the existing test `'warning shows Reroute button for same-opening matches only'` must be updated to seed a tree where the matched node has children (not a leaf), since the Reroute button now requires `!isLeaf(match.moveId)` in addition to `isSameOpening`.

**Dependencies:** Steps 5, 6.

## Risks / Open Questions

1. **Determining which buffered moves to persist.** The reroute needs to persist buffered moves "up to the convergence point." The convergence point is the focused pill's position (where the transposition was detected). The controller computes `bufferedCountToReroute = (focusedPillIndex + 1 - savedCount).clamp(0, bufferedMoves.length)` and slices `engine.bufferedMoves.sublist(0, bufferedCountToReroute)`. This is now a concrete part of Step 3, not just a risk note.

2. **What happens to buffered moves after the convergence point?** After reroute, the tree has changed and the engine state is stale. The plan calls `_loadData()` which rebuilds from scratch, discarding the engine's buffer. Any moves the user played past the convergence point are lost. This matches the task spec: the reroute replaces the current state with the rerouted line. If this is a concern, the controller could warn before rerouting when there are post-convergence buffered moves, or the Reroute button could be disabled in that case (the task notes mention this as a consideration).

3. **SAN conflict check timing.** The conflict check is done in-memory via `RepertoireTreeCache.getChildren()` in the controller before showing the confirmation dialog, so we can block early without a DB round-trip. When buffered moves are involved, the new convergence node does not exist yet, so there can be no existing children under it -- no conflict is possible. Only check when the convergence node already exists.

4. **Anchor move ID for insert.** When persisting buffered moves for the reroute, the "anchor" (parent of the first new move) is the last saved move on the current path. This is `engine.lastExistingMoveId` if no buffered moves have been played, or the last followed move's ID before the buffer starts. The engine tracks this as `_lastExistingMoveId`, which is correct.

5. **Sort order for re-parented moves.** After re-parenting children to the new convergence node, their `sort_order` values may conflict with existing children (if the convergence node was not freshly created). Since the conflict check blocks any SAN conflicts, and sort order is not unique-constrained, this should not cause errors. But the visual ordering of children may be unexpected. For v1, preserve existing sort orders; a future refinement could renumber them.

6. **Transaction atomicity.** The entire reroute (insert + re-parent + prune + labels) must be in a single database transaction. The `LocalRepertoireRepository.rerouteLine` method wraps everything in `_db.transaction(...)`, matching the pattern used by `extendLine` and `saveBranch`.

7. **Reroute button visibility when user has post-convergence buffered moves.** The task notes suggest considering whether to disable the Reroute button when the user has unsaved buffered moves after the convergence point. For simplicity, the initial implementation will allow reroute at any time (post-convergence moves will be discarded by the `_loadData` rebuild). A follow-up could add a warning or disable the button.

8. **Leaf match reroute is intentionally excluded.** Review issue #1 identified that rerouting a leaf match (matched node has no children) would be a no-op since the algorithm re-parents children. The plan gates the Reroute button on `!treeCache.isLeaf(match.moveId)`. A separate leaf-reroute flow (reparenting the node itself, handling review-card migration) is out of scope for this task and would need its own design if desired.
