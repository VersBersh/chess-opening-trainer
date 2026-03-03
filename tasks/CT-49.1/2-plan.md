# CT-49.1: Deferred Label Persistence -- Plan

## Goal

Replace the immediate DB write in `updateLabel()` with a local pending-labels map so that label edits on saved pills are held in controller state and only persisted on Confirm alongside moves.

## Steps

### 1. Add `_pendingLabels` map to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a private field to the controller:

```dart
/// Pending label changes for saved pills only, keyed by pill index.
/// Values are nullable strings: a String sets/updates the label, null removes it.
/// Entries are present only for pills whose labels have been edited in this session.
/// Buffered (unsaved) pills are NOT tracked here -- they use BufferedMove.label
/// via updateBufferedLabel(), which is already deferred.
final Map<int, String?> _pendingLabels = {};
```

Key the map by **pill index** (the same index used in `_buildPillsList()` output). This is simpler than keying by move ID because:
- Pill index is what the UI passes into `updateLabel()` and `updateBufferedLabel()`.
- The pill index is stable during a session: existing path + followed moves are immutable during entry, and take-back only removes buffered moves from the end (saved pill indices never shift).

Also add a public read-only accessor for testing:

```dart
Map<int, String?> get pendingLabels => Map.unmodifiable(_pendingLabels);
```

### 2. Rewrite `updateLabel()` to be synchronous and local-only

**File:** `src/lib/controllers/add_line_controller.dart`

Change `updateLabel()` from `Future<void>` to `void`. Remove all async logic: the `_repertoireRepo.updateMoveLabel()` call, the full cache rebuild, the buffered-move replay, and the `savedBufferedLabels`/`reapplyBufferedLabels` machinery.

New implementation:

```dart
void updateLabel(int pillIndex, String? newLabel) {
  // Store the pending label (or remove entry if reverting to original).
  final engine = _state.engine;
  if (engine == null) return;

  // Determine the original label from the engine data.
  final originalLabel = _getOriginalLabel(pillIndex);
  if (newLabel == originalLabel) {
    _pendingLabels.remove(pillIndex);
  } else {
    _pendingLabels[pillIndex] = newLabel;
  }

  // Rebuild pills with pending overlay and recompute display name.
  final pills = _buildPillsList(engine);
  final displayName = _computeDisplayNameWithPending(engine);

  _state = AddLineState(
    treeCache: _state.treeCache,
    engine: engine,
    boardOrientation: _state.boardOrientation,
    focusedPillIndex: _state.focusedPillIndex,
    currentFen: _state.currentFen,
    preMoveFen: _state.preMoveFen,
    aggregateDisplayName: displayName,
    isLoading: false,
    repertoireName: _state.repertoireName,
    pills: pills,
  );
  notifyListeners();
}
```

Add a helper `_getOriginalLabel(int pillIndex)` that reads the label from the engine's `existingPath` or `followedMoves` at the given index (same index arithmetic as `getMoveIdAtPillIndex`). Since `_pendingLabels` only covers saved pills, this helper only needs to handle `existingPath` and `followedMoves`:

```dart
String? _getOriginalLabel(int pillIndex) {
  final engine = _state.engine;
  if (engine == null) return null;

  final existingLen = engine.existingPath.length;
  final followedLen = engine.followedMoves.length;

  if (pillIndex < existingLen) {
    return engine.existingPath[pillIndex].label;
  } else if (pillIndex < existingLen + followedLen) {
    return engine.followedMoves[pillIndex - existingLen].label;
  }
  return null; // Buffered pill -- not handled here.
}
```

**Depends on:** Step 1.

### 3. Overlay pending labels in `_buildPillsList()`

**File:** `src/lib/controllers/add_line_controller.dart`

Modify `_buildPillsList()` to check `_pendingLabels` for saved pills (existing path and followed moves) and use the pending value instead of the move's stored label. Buffered pills are NOT overlaid from `_pendingLabels` -- they use `BufferedMove.label` directly (set via `updateBufferedLabel()`):

```dart
List<MovePillData> _buildPillsList(LineEntryEngine engine) {
  final pills = <MovePillData>[];
  var index = 0;

  for (final move in engine.existingPath) {
    final label = _pendingLabels.containsKey(index)
        ? _pendingLabels[index]
        : move.label;
    pills.add(MovePillData(san: move.san, isSaved: true, label: label));
    index++;
  }

  for (final move in engine.followedMoves) {
    final label = _pendingLabels.containsKey(index)
        ? _pendingLabels[index]
        : move.label;
    pills.add(MovePillData(san: move.san, isSaved: true, label: label));
    index++;
  }

  for (final buffered in engine.bufferedMoves) {
    // Buffered moves use BufferedMove.label set via updateBufferedLabel().
    // _pendingLabels is not consulted here.
    pills.add(MovePillData(san: buffered.san, isSaved: false, label: buffered.label));
    index++;
  }

  return pills;
}
```

**Depends on:** Step 1.

### 4. Add `_computeDisplayNameWithPending()` helper

**File:** `src/lib/controllers/add_line_controller.dart`

The current `engine.getCurrentDisplayName()` only considers labels stored in the tree cache. Add a private helper that overlays pending labels:

```dart
String _computeDisplayNameWithPending(LineEntryEngine engine) {
  final labels = <String>[];
  var index = 0;

  for (final move in engine.existingPath) {
    final label = _pendingLabels.containsKey(index)
        ? _pendingLabels[index]
        : move.label;
    if (label != null && label.isNotEmpty) labels.add(label);
    index++;
  }

  for (final move in engine.followedMoves) {
    final label = _pendingLabels.containsKey(index)
        ? _pendingLabels[index]
        : move.label;
    if (label != null && label.isNotEmpty) labels.add(label);
    index++;
  }

  for (final buffered in engine.bufferedMoves) {
    final label = buffered.label;
    if (label != null && label.isNotEmpty) labels.add(label);
    index++;
  }

  return labels.join(' \u2014 ');
}
```

Replace all calls to `engine.getCurrentDisplayName()` in the controller with `_computeDisplayNameWithPending(engine)` so that pending labels are always reflected in the aggregate display name banner.

**Depends on:** Step 1.

### 5. Add `getEffectiveLabelAtPillIndex()` to the controller

**File:** `src/lib/controllers/add_line_controller.dart`

The saved-pill label editor in `add_line_screen.dart` currently reads `move.label` from `getMoveAtPillIndex()` to initialize the `InlineLabelEditor.currentLabel`. After deferred edits, this still returns the original DB label, so reopening the editor would show the stale value and the editor's "unchanged" check (`labelToSave == widget.currentLabel`) would be wrong.

Add a public method that returns the effective (pending-aware) label at a pill index:

```dart
/// Returns the effective label at a pill index, considering pending edits.
/// For saved pills, returns the pending label if one exists, otherwise the
/// DB label. For unsaved pills, returns BufferedMove.label.
String? getEffectiveLabelAtPillIndex(int index) {
  if (_pendingLabels.containsKey(index)) {
    return _pendingLabels[index];
  }
  final engine = _state.engine;
  if (engine == null) return null;

  final existingLen = engine.existingPath.length;
  final followedLen = engine.followedMoves.length;

  if (index < existingLen) {
    return engine.existingPath[index].label;
  } else if (index < existingLen + followedLen) {
    return engine.followedMoves[index - existingLen].label;
  } else {
    final bufferedIndex = index - existingLen - followedLen;
    if (bufferedIndex < engine.bufferedMoves.length) {
      return engine.bufferedMoves[bufferedIndex].label;
    }
  }
  return null;
}
```

**Depends on:** Step 1.

### 6. Clear `_pendingLabels` on state-resetting operations

**File:** `src/lib/controllers/add_line_controller.dart`

Clear `_pendingLabels` at the start of:
- `loadData()` -- after successful persist or undo, the tree is reloaded from DB and pending labels are no longer relevant.
- The branching path in `onBoardMove()` where a new engine is created -- pending labels keyed by old pill indices are invalid after re-branching.

Specifically, add `_pendingLabels.clear();` as the first line of `loadData()`.

For the branching path in `onBoardMove()`, also clear `_pendingLabels` since the pill indices change when a new engine is created.

**Depends on:** Step 1.

### 7. Include pending labels in `confirmAndPersist()` flow and persist atomically

**File:** `src/lib/controllers/add_line_controller.dart`
**File:** `src/lib/services/line_persistence_service.dart`
**File:** `src/lib/repositories/repertoire_repository.dart`
**File:** `src/lib/repositories/local/local_repertoire_repository.dart`

This is the key integration step. On confirm, pending labels for saved (followed) moves must be written to the DB alongside the new moves in a single atomic transaction.

**a) Add a `PendingLabelUpdate` data class:**

Add to `line_persistence_service.dart`:

```dart
class PendingLabelUpdate {
  final int moveId;
  final String? label;
  const PendingLabelUpdate({required this.moveId, required this.label});
}
```

**b) Add new repository methods that combine label updates + move persistence in one transaction:**

The current `extendLine` and `saveBranch` repository methods each encapsulate their own `_db.transaction()` call. Calling `updateMoveLabel` outside those transactions would break atomicity -- a crash between label-update and move-insert could leave partial state. The correct fix is to add new repository methods (or extend existing ones) that perform both operations inside a single transaction.

Add to `RepertoireRepository` interface:

```dart
/// Extends a line AND applies pending label updates in one transaction.
Future<List<int>> extendLineWithLabelUpdates(
  int oldLeafMoveId,
  List<RepertoireMovesCompanion> newMoves,
  List<PendingLabelUpdate> labelUpdates,
);

/// Saves a branch AND applies pending label updates in one transaction.
Future<List<int>> saveBranchWithLabelUpdates(
  int? parentMoveId,
  List<RepertoireMovesCompanion> newMoves,
  List<PendingLabelUpdate> labelUpdates,
);
```

Implement in `LocalRepertoireRepository` by wrapping the existing logic plus label updates in a single `_db.transaction()`:

```dart
@override
Future<List<int>> extendLineWithLabelUpdates(
  int oldLeafMoveId,
  List<RepertoireMovesCompanion> newMoves,
  List<PendingLabelUpdate> labelUpdates,
) {
  return _db.transaction(() async {
    // Apply pending label updates first.
    for (final update in labelUpdates) {
      await (_db.update(_db.repertoireMoves)
            ..where((m) => m.id.equals(update.moveId)))
          .write(RepertoireMovesCompanion(label: Value(update.label)));
    }

    // Then perform the existing extendLine logic (inline, not calling
    // extendLine() which would try to open a nested transaction).
    await (_db.delete(_db.reviewCards)
          ..where((c) => c.leafMoveId.equals(oldLeafMoveId)))
        .go();

    final insertedIds = <int>[];
    int parentId = oldLeafMoveId;
    for (final move in newMoves) {
      final insertedId = await _db.into(_db.repertoireMoves).insert(
            move.copyWith(parentMoveId: Value(parentId)),
          );
      insertedIds.add(insertedId);
      parentId = insertedId;
    }

    if (insertedIds.isNotEmpty) {
      final newLeaf = await getMove(insertedIds.last);
      if (newLeaf != null) {
        await _db.into(_db.reviewCards).insert(
              ReviewCardsCompanion.insert(
                repertoireId: newLeaf.repertoireId,
                leafMoveId: newLeaf.id,
                nextReviewDate: DateTime.now(),
              ),
            );
      }
    }

    return insertedIds;
  });
}
```

Similarly for `saveBranchWithLabelUpdates`. Both methods duplicate the core transaction logic from `extendLine`/`saveBranch` but add label updates at the start. The original `extendLine` and `saveBranch` methods remain unchanged (they are still used by existing callers and undo paths).

**c) Update `LinePersistenceService.persistNewMoves()`:**

Accept an optional list of pending label updates and pass them through to the repository:

```dart
Future<PersistResult> persistNewMoves(
  ConfirmData confirmData, {
  List<PendingLabelUpdate> pendingLabelUpdates = const [],
}) async {
  if (confirmData.newMoves.isEmpty) {
    throw ArgumentError('confirmData.newMoves must not be empty');
  }
  if (confirmData.isExtension) {
    return _persistExtension(confirmData, pendingLabelUpdates: pendingLabelUpdates);
  } else {
    return _persistBranch(confirmData, pendingLabelUpdates: pendingLabelUpdates);
  }
}
```

In `_persistExtension`, call `_repertoireRepo.extendLineWithLabelUpdates(...)` instead of `extendLine(...)` when `pendingLabelUpdates` is non-empty (fall back to `extendLine` when empty for zero-overhead default path). Same pattern for `_persistBranch`.

**d) Build label updates in the controller's `_persistMoves()`:**

```dart
Future<ConfirmResult> _persistMoves(LineEntryEngine engine) async {
  final confirmData = engine.getConfirmData();

  // Build pending label updates for saved moves.
  final labelUpdates = <PendingLabelUpdate>[];
  for (final entry in _pendingLabels.entries) {
    final moveId = getMoveIdAtPillIndex(entry.key);
    if (moveId != null) {
      labelUpdates.add(PendingLabelUpdate(moveId: moveId, label: entry.value));
    }
  }

  try {
    final result = await _persistenceService.persistNewMoves(
      confirmData,
      pendingLabelUpdates: labelUpdates,
    );
    // ... rest unchanged (loadData clears _pendingLabels)
  }
}
```

**Depends on:** Steps 1, 2, 3, 4, 5, 6.

### 8. Update the `onSave` callback and `currentLabel` in `add_line_screen.dart`

**File:** `src/lib/screens/add_line_screen.dart`

Two changes are needed in `_buildSavedPillLabelEditor()`:

**a) Use effective label for `currentLabel`:**

The editor currently initializes with `move.label` from `getMoveAtPillIndex()`, which returns the DB value. After a deferred edit, reopening the editor would show the stale DB label. Use the new `getEffectiveLabelAtPillIndex()` instead:

```dart
Widget _buildSavedPillLabelEditor(AddLineState state, int focusedIndex) {
  final move = _controller.getMoveAtPillIndex(focusedIndex);
  if (move == null) return const SizedBox.shrink();

  final cache = state.treeCache;
  if (cache == null) return const SizedBox.shrink();

  final effectiveLabel = _controller.getEffectiveLabelAtPillIndex(focusedIndex);

  return InlineLabelEditor(
    key: ValueKey('label-editor-${move.id}'),
    currentLabel: effectiveLabel,
    moveId: move.id,
    // ... rest unchanged
```

**b) Simplify `onSave` callback:**

- `updateLabel` is now synchronous and returns `void` (no `await` needed).
- The board position reset after `updateLabel` is no longer needed (no tree reload, no engine rebuild, no FEN change).
- The label impact warning check still makes sense for saved pills (it consults the tree cache to warn about descendant name changes). Keep it, but note it checks the original tree cache, not pending state. This is acceptable -- the warning is advisory.

Updated `onSave`:

```dart
onSave: (label) async {
  final impact = cache.getDescendantLabelImpact(move.id, label);
  if (impact.isNotEmpty) {
    final confirmed = await showLabelImpactWarningDialog(
      context,
      affectedEntries: impact,
    );
    if (confirmed != true) {
      throw LabelChangeCancelledException();
    }
  }
  _controller.updateLabel(focusedIndex, label);
  // No board reset needed -- no tree reload occurred.
},
```

**Depends on:** Steps 2, 5.

### 9. Keep `updateLabel` and `updateBufferedLabel` as separate paths (design decision)

**File:** `src/lib/screens/add_line_screen.dart`

Currently the screen has separate code paths for saved vs. unsaved pill label editors (`_buildSavedPillLabelEditor` and `_buildUnsavedPillLabelEditor`). `_pendingLabels` is scoped to saved pills only. `updateBufferedLabel()` continues to work as it does today -- it mutates `BufferedMove.label` directly, and `ConfirmData` picks those labels up automatically.

No code changes in this step -- just a design decision confirming the two paths remain separate and consistent.

### 10. Verify `hasLineLabel` works with pending labels

**File:** `src/lib/controllers/add_line_controller.dart`

The `hasLineLabel` getter checks `aggregateDisplayName` and `pills` labels. Since `_buildPillsList` and `_computeDisplayNameWithPending` already overlay pending labels into the state, `hasLineLabel` reads the overlaid values and should work correctly without changes. Verify this in tests.

### 11. Update tests

**File:** `src/test/controllers/add_line_controller_test.dart`
**File:** `src/test/services/line_persistence_service_test.dart`

Update existing tests:
- **`updateLabel` tests** -- These currently verify the label is persisted to DB immediately. Change them to verify that the label goes into `_pendingLabels` instead, and that the DB is NOT updated until `confirmAndPersist()`.
- **`updateLabel preserves focusedPillIndex`** -- Should still pass since the new `updateLabel` preserves all state.
- **`updateLabel does not break subsequent branching`** -- Verify pending labels are cleared on branch.
- **`buffered labels are preserved when updateLabel is called on a saved move`** -- This test was needed because the old `updateLabel` did a full reload. The new version does not reload, so buffered moves are trivially preserved. Simplify or remove the saved-buffered-labels machinery test.

Add new tests:
- `updateLabel stores pending label in _pendingLabels map`.
- `updateLabel with original value removes entry from _pendingLabels` (revert case).
- `_buildPillsList overlays pending labels onto saved pill data only`.
- `getEffectiveLabelAtPillIndex returns pending label when one exists`.
- `getEffectiveLabelAtPillIndex returns DB label when no pending edit`.
- `confirmAndPersist persists pending labels alongside moves atomically`.
- `pending labels are discarded when screen is abandoned` (controller disposed).
- `pending labels are cleared after successful confirm` (via `loadData()`).
- `pending labels are cleared on branch` (via `onBoardMove` branching path).
- `persistNewMoves with label updates calls extendLineWithLabelUpdates`.

**Depends on:** All previous steps.

## Risks / Open Questions

1. **Label-only edits with no new moves:** If the user follows an existing line and only edits labels (no new moves), `hasNewMoves` is `false` and the Confirm button is disabled. The pending labels would be silently discarded on screen exit. The spec says Confirm is disabled when following an existing line exactly (CT-49.3 addresses the info text for this). For CT-49.1, this means label-only edits on fully-existing lines cannot be saved. This may be acceptable for v0 -- the Repertoire Manager already supports direct label editing. If this is a problem, a follow-up task could enable Confirm when `_pendingLabels.isNotEmpty` even if `!hasNewMoves`, but that requires additional persistence logic (persist labels without moves).

2. **Pending labels and branching:** When the user branches from a focused pill, a new engine is created and pill indices change. `_pendingLabels` must be cleared in this path. Any labels the user edited before branching are lost. This seems acceptable since branching is a significant navigation action that changes the builder's context.

3. **Repository code duplication:** The new `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates` methods duplicate the core transaction logic from `extendLine`/`saveBranch`. This is intentional -- Drift does not support joining nested transactions, so the label updates must be inside the same `_db.transaction()` call. A private helper could extract the shared insert-chain logic to reduce duplication, but that is an implementation detail to be decided during coding.

4. **`InlineLabelEditor.onSave` signature:** The `onSave` callback is typed as `Future<void> Function(String? label)`. Since `updateLabel` becomes synchronous, the callback can still return a completed future (an `async` function that does synchronous work). No signature change needed on the widget side.

5. **Display name preview in `InlineLabelEditor`:** The `previewDisplayName` callback for saved pills currently calls `cache.previewAggregateDisplayName(move.id, text)`, which only considers the tree cache (not pending labels on other pills). This means the preview may be inaccurate if the user has pending labels on ancestor pills. This is a minor UX imperfection acceptable for v0 -- the aggregate banner above the board does show the full pending-aware display name.

6. **Review Issue 3 (take-back cleanup) -- not applicable:** The original plan included a Step 11 for cleaning up pending labels during take-back. This was based on a misunderstanding: `canTakeBack()` only returns true when `_bufferedMoves.isNotEmpty` (line_entry_engine.dart:162), meaning take-back can only remove buffered (unsaved) pills. Since `_pendingLabels` is scoped to saved pills only, take-back can never remove a pill that has a pending label entry. No take-back cleanup is needed.
