# CT-59: Implementation Plan

## Goal

Enable the Confirm button and persist label changes when a user edits labels on existing moves without adding new moves.

## Steps

### 1. Add `hasPendingLabelChanges` getter to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a public getter:

```dart
bool get hasPendingLabelChanges => _pendingLabels.isNotEmpty;
```

This gives both the screen and the controller's own `confirmAndPersist` a clean way to check for label-only edits.

### 2. Add `hasUnsavedChanges` computed property to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a property that unifies both change types:

```dart
bool get hasUnsavedChanges => hasNewMoves || hasPendingLabelChanges;
```

This replaces the many call sites that currently check only `hasNewMoves`.

### 3. Add `batchUpdateLabels` transaction method to repository layer

**File:** `src/lib/repositories/repertoire_repository.dart`

Add a new abstract method:

```dart
/// Applies multiple label updates in a single transaction.
Future<void> batchUpdateLabels(List<PendingLabelUpdate> labelUpdates);
```

**File:** `src/lib/repositories/local/local_repertoire_repository.dart`

Implement it as a transactional batch write, matching the pattern used by `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates`:

```dart
@override
Future<void> batchUpdateLabels(List<PendingLabelUpdate> labelUpdates) {
  return _db.transaction(() async {
    for (final update in labelUpdates) {
      await (_db.update(_db.repertoireMoves)
            ..where((m) => m.id.equals(update.moveId)))
          .write(RepertoireMovesCompanion(label: Value(update.label)));
    }
  });
}
```

This ensures atomicity: either all label updates succeed or none do, consistent with the existing multi-write transaction patterns in the repository.

### 4. Add `persistLabelsOnly` method to `LinePersistenceService`

**File:** `src/lib/services/line_persistence_service.dart`

Add a method that applies pending label updates without inserting any moves:

```dart
Future<void> persistLabelsOnly(List<PendingLabelUpdate> labelUpdates) async {
  await _repertoireRepo.batchUpdateLabels(labelUpdates);
}
```

This delegates to the new transactional repository method from step 3.

### 5. Update `confirmAndPersist()` to handle label-only edits

**File:** `src/lib/controllers/add_line_controller.dart`

Modify the early-return guard in `confirmAndPersist()`. Currently:

```dart
if (engine == null || !engine.hasNewMoves) {
  return const ConfirmNoNewMoves();
}
```

Change to:

```dart
if (engine == null) return const ConfirmNoNewMoves();

if (!engine.hasNewMoves && _pendingLabels.isEmpty) {
  return const ConfirmNoNewMoves();
}

if (!engine.hasNewMoves && _pendingLabels.isNotEmpty) {
  // Label-only persist path.
  return _persistLabelsOnly();
}
```

Then add a new private method `_persistLabelsOnly()` that:
1. Increments `_undoGeneration` to invalidate any stale undo snackbar from a prior confirm.
2. Builds `PendingLabelUpdate` list from `_pendingLabels` (same logic as in `_persistMoves`).
3. Calls `_persistenceService.persistLabelsOnly(labelUpdates)`.
4. Refreshes state **in-place** without calling `_loadData()` (see detail below).
5. Returns a `ConfirmSuccess` with `isExtension: false` and empty `insertedMoveIds`.

**In-place state refresh (avoiding `_loadData()` position reset):**

`_loadData()` resets the engine from scratch, which moves the focused pill to the leaf and changes the board position. For a label-only save, the user's current pill focus and board position must be preserved. Instead of calling `_loadData()`:

1. Clear `_pendingLabels` (they have been persisted).
2. Reload the tree cache from DB: `await _repertoireRepo.getMovesForRepertoire(...)` and `RepertoireTreeCache.build(...)`.
3. Rebuild a new `LineEntryEngine` from the updated cache, using the current leaf move ID (the last saved pill's move ID) so the engine path is identical to what the user sees.
4. Capture the current `focusedPillIndex`, `currentFen`, `preMoveFen`, and `boardOrientation` before rebuilding state.
5. Rebuild pills via `_buildPillsList(newEngine)` and recompute the display name.
6. Emit the new `AddLineState` with the captured focus/FEN/orientation values, not the leaf-default values that `_loadData` would produce.

Wrap in try/catch matching the existing error handling pattern. On error, call `_loadData()` to restore consistent state (acceptable to lose position on error).

```dart
Future<ConfirmResult> _persistLabelsOnly() async {
  _undoGeneration++;

  final labelUpdates = <PendingLabelUpdate>[];
  for (final entry in _pendingLabels.entries) {
    final moveId = getMoveIdAtPillIndex(entry.key);
    if (moveId != null) {
      labelUpdates.add(PendingLabelUpdate(moveId: moveId, label: entry.value));
    }
  }

  try {
    await _persistenceService.persistLabelsOnly(labelUpdates);

    // Refresh cache and engine in-place, preserving position.
    final savedFocusedPillIndex = _state.focusedPillIndex;
    final savedCurrentFen = _state.currentFen;
    final savedPreMoveFen = _state.preMoveFen;

    _pendingLabels.clear();

    final allMoves = await _repertoireRepo.getMovesForRepertoire(_repertoireId);
    final cache = RepertoireTreeCache.build(allMoves);

    // Determine the leaf move ID for the engine: the last saved pill.
    final oldEngine = _state.engine!;
    final savedMoves = [...oldEngine.existingPath, ...oldEngine.followedMoves];
    final leafMoveId = savedMoves.isNotEmpty ? savedMoves.last.id : _startingMoveId;

    final engine = LineEntryEngine(
      treeCache: cache,
      repertoireId: _repertoireId,
      startingMoveId: leafMoveId,
    );

    final pills = _buildPillsList(engine);
    final displayName = _computeDisplayNameWithPending(engine);
    final transpositions = _computeTranspositions(
      engine, savedCurrentFen, savedFocusedPillIndex);

    _state = AddLineState(
      treeCache: cache,
      engine: engine,
      boardOrientation: _state.boardOrientation,
      focusedPillIndex: savedFocusedPillIndex,
      currentFen: savedCurrentFen,
      preMoveFen: savedPreMoveFen,
      aggregateDisplayName: displayName,
      isLoading: false,
      repertoireName: _state.repertoireName,
      pills: pills,
      transpositionMatches: transpositions,
      showHintArrows: _state.showHintArrows,
    );
    notifyListeners();

    return const ConfirmSuccess(
      isExtension: false,
      insertedMoveIds: [],
    );
  } on Object catch (e) {
    await _loadData();
    return ConfirmError(
      userMessage: 'Could not save labels. Please try again.',
      error: e,
    );
  }
}
```

**Why no new `ConfirmLabelsOnly` result type:** The existing `ConfirmSuccess` with empty `insertedMoveIds` is sufficient. `_handleConfirmSuccess` in the screen already skips undo snackbars when `insertedMoveIds` is empty (the extension path requires `oldCard != null`, the new-line path requires `insertedMoveIds.isNotEmpty`). Adding a separate sealed subtype would require updating both `_onConfirmLine` and `_onFlipAndConfirm` switch/if blocks for no behavioral difference.

### 6. Update `flipAndConfirm()` to handle label-only edits

**File:** `src/lib/controllers/add_line_controller.dart`

Apply the same guard change as step 5. When `!engine.hasNewMoves && _pendingLabels.isNotEmpty`, call `_persistLabelsOnly()` directly (parity validation is irrelevant when there are no new moves):

```dart
Future<ConfirmResult> flipAndConfirm() async {
  final engine = _state.engine;
  if (engine == null) return const ConfirmNoNewMoves();

  if (!engine.hasNewMoves && _pendingLabels.isEmpty) {
    return const ConfirmNoNewMoves();
  }

  if (!engine.hasNewMoves && _pendingLabels.isNotEmpty) {
    return _persistLabelsOnly();
  }

  // ... existing flip + parity check + _persistMoves logic unchanged ...
}
```

Note: `_persistLabelsOnly()` already increments `_undoGeneration`, so stale undo snackbars from a prior confirm are correctly invalidated on this path too.

### 7. Update `_onConfirmLine` in the screen to handle label-only confirms

**File:** `src/lib/screens/add_line_screen.dart`

**a)** Change the early-return guard from `if (!_controller.hasNewMoves) return;` to `if (!_controller.hasUnsavedChanges) return;`. This allows label-only edits through to `confirmAndPersist()`.

**b)** No new switch case needed: `_persistLabelsOnly()` returns `ConfirmSuccess`, which is already handled by the existing `case ConfirmSuccess():` branch. The `_handleConfirmSuccess` method naturally skips undo snackbars when `insertedMoveIds` is empty.

**c)** The no-name-warning dialog guard (`!_controller.hasLineLabel`) should still apply. For label-only edits, the user is editing an existing line that likely already has labels, so the check is harmless.

### 8. Update Confirm button enable/disable in `_buildActionBar`

**File:** `src/lib/screens/add_line_screen.dart`

Change:

```dart
onPressed: _controller.hasNewMoves ? _onConfirmLine : null,
```

To:

```dart
onPressed: _controller.hasUnsavedChanges ? _onConfirmLine : null,
```

### 9. Update `PopScope.canPop` and `isExistingLine`

**File:** `src/lib/screens/add_line_screen.dart`

Change the PopScope guard from `!_controller.hasNewMoves` to `!_controller.hasUnsavedChanges` so that navigating away with pending label edits triggers the discard dialog.

**File:** `src/lib/controllers/add_line_controller.dart`

Update `isExistingLine`:

```dart
bool get isExistingLine =>
    _state.pills.isNotEmpty && !hasNewMoves && !hasPendingLabelChanges;
```

This prevents the "Existing line" info label from showing when labels have been edited.

### 10. Update snackbar-dismiss logic

**File:** `src/lib/screens/add_line_screen.dart`

In `_onControllerChanged`, the snackbar dismiss uses `_controller.hasNewMoves`. This should remain unchanged -- snackbar dismissal is about the first *move* of a new variation, not label edits. No change needed here.

### 11. Add widget test for label-only confirm flow

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests in the existing `AddLineScreen` group:

**a) Happy-path confirm:**

```
testWidgets('confirm enabled and persists label-only edits', ...)
```

Test steps:
1. Seed a repertoire with an existing line `['e4', 'e5']` and a label on `e4`.
2. Pump the screen with `startingMoveId` pointing to `e5` (so the user is at the end of an existing line).
3. Verify the Confirm button is initially disabled.
4. Tap the `e4` pill, then re-tap to open the label editor, change the label.
5. Verify the Confirm button is now enabled.
6. Tap Confirm.
7. Verify the label is persisted in the DB (query the move and check its label).
8. Verify the Confirm button is disabled again after confirm.

**b) Focus/board position preserved after label-only save:**

```
testWidgets('label-only confirm preserves focused pill and board position', ...)
```

Test steps:
1. Seed a repertoire with an existing line `['e4', 'e5', 'Nf3']`.
2. Pump the screen with `startingMoveId` pointing to `Nf3`.
3. Tap the `e4` pill (pill index 0) to focus and navigate the board there.
4. Open the label editor and change the label on `e4`.
5. Tap Confirm.
6. Verify the focused pill index is still 0 (on `e4`).
7. Verify the board FEN matches the position after `e4` (not the leaf position).

**c) Discard dialog with pending labels only:**

```
testWidgets('discard dialog shown when only pending labels exist', ...)
```

Test steps:
1. Seed a repertoire with an existing line.
2. Pump the screen, change a label (no new moves).
3. Attempt to pop/navigate back.
4. Verify the discard dialog appears.

**d) Stale undo invalidation after label-only save:**

```
testWidgets('label-only confirm invalidates prior undo snackbar', ...)
```

Test steps:
1. Seed a repertoire, add new moves, confirm (produces undo snackbar).
2. Follow along existing moves (no new moves), edit a label, confirm labels only.
3. Tap the undo action on the stale snackbar.
4. Verify the undo is a no-op (generation mismatch).

### 12. Add unit test in controller tests

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests:

**a) Happy-path:**

```
test('confirmAndPersist persists label-only edits when no new moves', ...)
```

Test steps:
1. Seed a repertoire with `['e4']`.
2. Create controller with `startingMoveId` pointing to `e4`.
3. Load data.
4. Call `updateLabel(0, 'Sicilian')`.
5. Verify `hasPendingLabelChanges` is true and `hasNewMoves` is false.
6. Verify `hasUnsavedChanges` is true.
7. Call `confirmAndPersist()`.
8. Verify the result is `ConfirmSuccess` with empty `insertedMoveIds`.
9. Verify the label is updated in the DB.
10. Verify `pendingLabels` is empty after confirm.

**b) Focus preservation:**

```
test('label-only confirm preserves focusedPillIndex and currentFen', ...)
```

Test steps:
1. Seed a repertoire with `['e4', 'e5', 'Nf3']`.
2. Create controller, load data (focused at pill index 2, the leaf).
3. Navigate to pill index 0 (`e4`).
4. Call `updateLabel(0, 'King Pawn')`.
5. Call `confirmAndPersist()`.
6. Verify `state.focusedPillIndex` is 0.
7. Verify `state.currentFen` is the FEN after `1. e4`.

**c) Undo generation increment:**

```
test('label-only confirm increments undoGeneration', ...)
```

Test steps:
1. Seed and load controller.
2. Record `undoGeneration`.
3. Edit a label and call `confirmAndPersist()`.
4. Verify `undoGeneration` has incremented.

**d) flipAndConfirm with label-only:**

```
test('flipAndConfirm persists label-only edits when no new moves', ...)
```

Test steps:
1. Seed, load, edit label, call `flipAndConfirm()`.
2. Verify result is `ConfirmSuccess` with empty `insertedMoveIds`.
3. Verify label persisted in DB.

## Risks / Open Questions

1. **In-place state refresh correctness:** The label-only path rebuilds the engine from a fresh tree cache but restores the captured `focusedPillIndex`, `currentFen`, and `preMoveFen`. If the focused pill index no longer maps to the same move after the cache rebuild (e.g., due to a concurrent external DB change), the restored position could be wrong. This is an edge case with no practical trigger in single-user mode, and the fallback on error (`_loadData()`) recovers cleanly.

2. **Discard dialog wording:** The current discard dialog says "You have unsaved moves. Do you want to discard them?" For label-only edits, this is slightly misleading. Consider updating the message to "You have unsaved changes." This is a minor UX polish that could be addressed in this task or deferred.

3. **No-name warning on label-only confirm:** The no-name warning dialog fires when `!_controller.hasLineLabel`. For label-only edits, the user is editing an existing line that likely already has labels. The check should be harmless, but verify it doesn't unexpectedly fire during the label-only path. If the user is *removing* the only label, the warning would fire, which seems correct.

4. **Label-only confirm feedback:** With the `ConfirmSuccess` approach, `_handleConfirmSuccess` skips both undo snackbars when `insertedMoveIds` is empty. The user gets no explicit feedback that labels were saved. Consider showing a brief "Labels saved" snackbar for user reassurance. This can be done by checking `insertedMoveIds.isEmpty` in `_handleConfirmSuccess` and showing a simple (non-undo) snackbar. This is optional and can be added during implementation if desired.

5. **`_handleConfirmSuccess` board sync for label-only:** `_handleConfirmSuccess` calls `_boardController.setPosition(fen)` using `_controller.state.currentFen`. Since the label-only path preserves `currentFen` in the state, this will correctly set the board to the user's current position (not the leaf). This is the desired behavior -- no additional change is needed in `_handleConfirmSuccess`.
