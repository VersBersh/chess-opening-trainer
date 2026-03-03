# CT-43: Implementation Plan

## Goal

Enable the Label button whenever any pill is focused (saved or unsaved), allowing users to add labels to unsaved (buffered) moves that are persisted when the line is confirmed.

## Steps

### Step 1: Add `label` field to `BufferedMove`

**File:** `src/lib/services/line_entry_engine.dart`

Add an optional `label` field to the `BufferedMove` class:

```dart
class BufferedMove {
  final String san;
  final String fen;
  String? label;
  BufferedMove({required this.san, required this.fen, this.label});
}
```

Change from `const` constructor to a regular constructor since `label` must be mutable (the user may edit it after the move is buffered). Remove the `const` from the constructor. Also update `acceptMove()` (line 147) which currently constructs `BufferedMove` without `const` already, and the `NewMoveBuffered` result class which uses `const` — both are fine since `BufferedMove` itself just loses `const` capability.

**Dependencies:** None. This is the foundational data model change.

### Step 2: Add `setBufferedLabel` method to `LineEntryEngine`

**File:** `src/lib/services/line_entry_engine.dart`

Add a method to mutate labels on buffered moves:

```dart
void setBufferedLabel(int index, String? label) {
  if (index >= 0 && index < _bufferedMoves.length) {
    _bufferedMoves[index].label = label;
  }
}
```

Also add a method to bulk-apply labels to buffered moves after a replay (needed for Step 6):

```dart
void reapplyBufferedLabels(List<String?> labels) {
  for (var i = 0; i < labels.length && i < _bufferedMoves.length; i++) {
    _bufferedMoves[i].label = labels[i];
  }
}
```

**Dependencies:** Step 1.

### Step 3: Remove the `isSaved` guard from `canEditLabel`

**File:** `src/lib/controllers/add_line_controller.dart`

In the `canEditLabel` getter (line ~598), remove the line:
```dart
if (!_state.pills[focusedIndex].isSaved) return false;
```

The getter should only check that a pill is focused and within bounds:
```dart
bool get canEditLabel {
  final focusedIndex = _state.focusedPillIndex;
  if (focusedIndex == null) return false;
  if (focusedIndex >= _state.pills.length) return false;
  return true;
}
```

**Dependencies:** None.

### Step 4: Remove the `isSaved` assertion from `MovePillData`

**File:** `src/lib/widgets/move_pills_widget.dart`

Remove the assert on line 39:
```dart
}) : assert(isSaved || label == null, 'Only saved moves can have labels');
```

Change to just:
```dart
});
```

This allows unsaved pills to carry a label for display.

**Dependencies:** None.

### Step 5: Pass buffered move labels through to `MovePillData` in `_buildPillsList`

**File:** `src/lib/controllers/add_line_controller.dart`

In `_buildPillsList()`, update the loop that builds pills for buffered moves (lines ~210-215) to include the label:

```dart
for (final buffered in engine.bufferedMoves) {
  pills.add(MovePillData(
    san: buffered.san,
    isSaved: false,
    label: buffered.label,
  ));
}
```

**Dependencies:** Steps 1, 4.

### Step 6: Add `updateBufferedLabel` method to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a new method to update a label on a buffered (unsaved) move. Unlike `updateLabel()` (which writes to the DB and rebuilds the engine), this method simply mutates the in-memory `BufferedMove.label` and rebuilds pills:

```dart
void updateBufferedLabel(int pillIndex, String? newLabel) {
  final engine = _state.engine;
  if (engine == null) return;

  final existingLen = engine.existingPath.length;
  final followedLen = engine.followedMoves.length;
  final bufferedIndex = pillIndex - existingLen - followedLen;

  if (bufferedIndex < 0 || bufferedIndex >= engine.bufferedMoves.length) return;

  engine.setBufferedLabel(bufferedIndex, newLabel);

  final pills = _buildPillsList(engine);
  final displayName = engine.getCurrentDisplayName();

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

**Dependencies:** Step 2.

### Step 7: Preserve buffered labels during `updateLabel()` replay

**File:** `src/lib/controllers/add_line_controller.dart`

The existing `updateLabel()` method (line 612) replays buffered moves after rebuilding the engine via `engine.acceptMove(buffered.san, buffered.fen)`. This replay creates fresh `BufferedMove` instances with no label, which would silently drop any labels the user had set on buffered moves.

Fix: snapshot the labels before replay, then reapply them after:

```dart
// Existing snapshot (line 618):
final savedBufferedMoves = List.of(_state.engine?.bufferedMoves ?? []);
// Add: capture labels from the snapshot.
final savedBufferedLabels = savedBufferedMoves.map((b) => b.label).toList();

// ... (existing code: DB update, cache rebuild, engine creation) ...

// Existing replay (line 648):
for (final buffered in savedBufferedMoves) {
  engine.acceptMove(buffered.san, buffered.fen);
}

// Add: reapply labels after replay.
engine.reapplyBufferedLabels(savedBufferedLabels);
```

**Dependencies:** Steps 1, 2.

### Step 8: Propagate buffered labels through `ConfirmData` to persistence

**File:** `src/lib/services/line_persistence_service.dart`

First, add the Drift `Value` import. The file currently imports `database.dart` which itself imports `package:drift/drift.dart`, but that import is not re-exported — `Value` is not transitively available. Add an explicit import at the top of the file:

```dart
import 'package:drift/drift.dart' show Value;
```

Then, in both `_persistExtension` and `_persistBranch`, when building `RepertoireMovesCompanion` from buffered moves, include the label if present:

```dart
companions.add(RepertoireMovesCompanion.insert(
  repertoireId: confirmData.repertoireId,
  fen: buffered.fen,
  san: buffered.san,
  label: buffered.label != null ? Value(buffered.label) : const Value.absent(),
  sortOrder: i == 0 ? confirmData.sortOrder : 0,
));
```

**Dependencies:** Step 1.

### Step 9: Update `_onPillTapped` to allow re-tap label editing for unsaved pills

**File:** `src/lib/screens/add_line_screen.dart`

In `_onPillTapped` (line ~117), remove the `pill.isSaved` condition so that re-tapping any focused pill opens the inline editor:

```dart
if (isSameAsFocused && pill != null) {
  // Re-tap on a focused pill: open the inline editor.
  setState(() => _isLabelEditorVisible = true);
  return;
}
```

**Dependencies:** None.

### Step 10: Adapt `_buildInlineLabelEditor` for unsaved pills

**File:** `src/lib/screens/add_line_screen.dart`

Currently, `_buildInlineLabelEditor` calls `getMoveAtPillIndex(focusedIndex)` which returns `null` for buffered moves, causing the widget to return `SizedBox.shrink()`. The method must handle both saved and unsaved pills.

Replace the existing `_buildInlineLabelEditor` with logic that branches on whether the pill is saved:

**For saved pills:** Keep the existing logic unchanged (uses `RepertoireMove`, `moveId`, tree-cache operations).

**For unsaved pills:** Build a simplified `InlineLabelEditor` that:
- Uses a synthetic/placeholder key (e.g., `ValueKey('label-editor-unsaved-$focusedIndex')`)
- Gets `currentLabel` from the `MovePillData.label` (or the buffered move directly)
- Uses `moveId: -1` or a negative sentinel like `-focusedIndex - 1` (see Risk 1 below)
- Sets `descendantLeafCount: 0` (no descendants for unsaved moves)
- Provides a simple `previewDisplayName` that returns the label text itself (unsaved moves are not in the tree, so there is no aggregate path to preview)
- Has no `onCheckConflicts` (no conflicts possible for unsaved moves)
- `onSave` calls `_controller.updateBufferedLabel(focusedIndex, label)` instead of `_controller.updateLabel()`

Concretely:
```dart
Widget _buildInlineLabelEditor(AddLineState state) {
  final focusedIndex = state.focusedPillIndex;
  if (focusedIndex == null) return const SizedBox.shrink();

  final pill = focusedIndex < state.pills.length ? state.pills[focusedIndex] : null;
  if (pill == null) return const SizedBox.shrink();

  if (pill.isSaved) {
    return _buildSavedPillLabelEditor(state, focusedIndex);
  } else {
    return _buildUnsavedPillLabelEditor(state, focusedIndex, pill);
  }
}
```

Extract the current saved-pill logic into `_buildSavedPillLabelEditor` and create `_buildUnsavedPillLabelEditor`.

**Dependencies:** Steps 6, 9.

### Step 11: Update existing tests

**File:** `src/test/controllers/add_line_controller_test.dart`

- Line 1015: Change `expect(controller.canEditLabel, false)` to `expect(controller.canEditLabel, true)` — unsaved pills now allow label editing.

**File:** `src/test/screens/add_line_screen_test.dart`

- Review existing label-related tests and update expectations as needed.

**Dependencies:** Steps 3, 4, 5, 6, 7, 8, 9, 10.

### Step 12: Add new tests for unsaved pill label editing

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests:
1. `canEditLabel returns true when focused on an unsaved pill`
2. `updateBufferedLabel sets label on buffered move and rebuilds pills`
3. `buffered labels are preserved across take-back and re-entry` (take back does not lose labels on remaining buffered moves)
4. `buffered labels are preserved when updateLabel is called on a saved move` — verifies that the replay in `updateLabel()` does not drop buffered labels
5. `buffered labels are persisted on confirm` — after confirm, verify the DB move has the label set.

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests:
1. `label button enabled when unsaved pill is focused`
2. `double-tap unsaved pill opens label editor`
3. `label entered on unsaved pill is displayed on the pill`

**File:** `src/test/services/line_entry_engine_test.dart`

Add tests:
1. `setBufferedLabel mutates label on the correct buffered move`
2. `reapplyBufferedLabels restores labels after replay`
3. `buffered move labels survive take-back of later moves` (takeBack on the last move does not affect labels on earlier buffered moves)

**File:** `src/test/services/line_persistence_service_test.dart`

Add tests:
1. `persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for extensions`
2. `persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for branches`

**Dependencies:** All prior steps.

## Risks / Open Questions

1. **`InlineLabelEditor` requires `moveId: int`.** Unsaved moves have no ID. Options:
   - (a) Change `moveId` to `int?` in the widget. This would require auditing the widget and its `ValueKey` usage.
   - (b) Use a sentinel value like `-focusedIndex - 1` (negative, guaranteed not to collide with real auto-increment IDs). The `moveId` is only used in `ValueKey` and is passed to `onSave` — for unsaved pills, the `onSave` callback already knows the pill index, so the `moveId` value is irrelevant.
   - **Recommendation:** Option (b) is simpler and avoids changing the shared widget's API, which is also used by the Repertoire Browser screen.

2. **Label preview for unsaved moves.** The `previewDisplayName` callback on `InlineLabelEditor` is currently backed by `cache.previewAggregateDisplayName(moveId, text)`. For unsaved moves, there is no cache entry. A simple fallback (returning the label text itself, or computing the aggregate from the parent's path + the new label) should suffice for a usable preview.

3. **Buffered move labels lost on take-back.** When the user takes back the last buffered move via `takeBack()`, that `BufferedMove` is removed from the list, and its label is lost. This is acceptable behavior — the move itself is being discarded, so its label goes with it. However, labels on *remaining* buffered moves are preserved because `takeBack()` only calls `removeLast()`.

4. **`BufferedMove` mutability.** Adding a mutable `label` field to `BufferedMove` changes it from an immutable `const` class. The `const BufferedMove(...)` usage in the constructor declaration must drop the `const`. In tests and other call sites that construct `BufferedMove` directly, the `const` keyword must also be removed. This is a minor but potentially widespread change — grep for `const BufferedMove` and update all occurrences.

5. **Drift `Value` type in `line_persistence_service.dart`.** The file imports `database.dart`, which itself imports `package:drift/drift.dart` but does not re-export it. The `Value` type is therefore **not** transitively available. Step 8 explicitly adds `import 'package:drift/drift.dart' show Value;` to resolve this.
