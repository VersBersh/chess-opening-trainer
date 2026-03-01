# CT-2.3 Plan

## Goal

Add the ability to attach, edit, and remove labels on any move node via a dialog in the repertoire browser, with a live aggregate display name preview, updating the database and refreshing the tree cache.

## Steps

### 1. Add `updateMoveLabel` to the repository interface

**File:** `src/lib/repositories/repertoire_repository.dart`

Add a new method to the abstract `RepertoireRepository` class:

```dart
/// Updates just the label field on an existing move. Pass null to remove the label.
Future<void> updateMoveLabel(int moveId, String? label);
```

This is a targeted update -- it only touches the `label` column, leaving all other fields (fen, san, parent_move_id, sort_order) unchanged. It follows the principle of least change for a metadata-only operation.

**Depends on:** Nothing.

### 2. Update all `RepertoireRepository` fakes/mocks

**Files:**
- `src/test/screens/home_screen_test.dart` -- `FakeRepertoireRepository` and `_SlowRepertoireRepository` (inherits)
- `src/test/screens/drill_screen_test.dart` -- `FakeRepertoireRepository`

Both fakes `implement RepertoireRepository` and will fail to compile after Step 1 adds the new method. Add a minimal stub implementation to each:

```dart
@override
Future<void> updateMoveLabel(int moveId, String? label) async {}
```

This is a no-op stub since neither the home screen nor drill screen tests exercise label editing. The browser screen tests use `LocalRepertoireRepository` with a real in-memory database, so they do not need a fake.

**Depends on:** Step 1.

### 3. Implement `updateMoveLabel` in the local repository

**File:** `src/lib/repositories/local/local_repertoire_repository.dart`

Implement the new method using Drift's `update` + `write` pattern (matching the pattern in `LocalReviewRepository.saveReview`):

```dart
@override
Future<void> updateMoveLabel(int moveId, String? label) async {
  await (_db.update(_db.repertoireMoves)
        ..where((m) => m.id.equals(moveId)))
      .write(RepertoireMovesCompanion(label: Value(label)));
}
```

Key detail: `Value(null)` in Drift writes NULL to the column (removing the label), which is distinct from `Value.absent()` (which would skip the column). This is the correct behavior for clearing a label.

**Depends on:** Step 1.

### 4. Write unit tests for `updateMoveLabel`

**File:** `src/test/repositories/local_repertoire_repository_test.dart` (new file, or add to existing if one exists)

Test cases:
- **Set a label on an unlabeled move:** Insert a move with no label, call `updateMoveLabel(moveId, 'Sicilian')`, fetch the move, verify `label == 'Sicilian'`.
- **Change an existing label:** Insert a move with label 'Sicilian', call `updateMoveLabel(moveId, 'Sicilian Defense')`, verify the label changed.
- **Remove a label (set to null):** Insert a move with label 'Sicilian', call `updateMoveLabel(moveId, null)`, verify `label == null`.
- **Only label field changes:** After calling `updateMoveLabel`, verify all other fields (fen, san, parentMoveId, sortOrder) remain unchanged.

Use the `createTestDatabase()` helper pattern from the existing test files.

**Depends on:** Steps 2, 3.

### 5. Add `previewAggregateDisplayName` to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

Add a helper method to the `RepertoireTreeCache` class. This method takes a `moveId` and a `newLabel` (nullable), and computes the aggregate display name as if the move's label were replaced with `newLabel`. This is used by the dialog to show a live preview as the user types.

```dart
/// Computes what the aggregate display name would be if [moveId]'s label
/// were changed to [newLabel]. If [newLabel] is null or empty, the move's
/// label contribution is excluded.
String previewAggregateDisplayName(int moveId, String? newLabel) {
  final line = getLine(moveId);
  final labels = <String>[];
  for (final m in line) {
    if (m.id == moveId) {
      if (newLabel != null && newLabel.isNotEmpty) labels.add(newLabel);
    } else if (m.label != null) {
      labels.add(m.label!);
    }
  }
  return labels.join(' \u2014 ');
}
```

Note: The separator is ` \u2014 ` (em dash, Unicode U+2014), matching the existing `getAggregateDisplayName` implementation. The spec prose uses `" -- "` (double hyphen) as an ASCII approximation, but the actual code consistently uses an em dash.

**Depends on:** Nothing.

### 6. Write unit tests for `previewAggregateDisplayName`

**File:** `src/test/models/repertoire_tree_cache_test.dart` (extend existing file)

Test cases:
- **Preview adding a label to an unlabeled node on a path with no other labels:** Returns just the new label.
- **Preview adding a label to a node whose ancestor has a label:** Returns `'AncestorLabel \u2014 NewLabel'` (em dash separator).
- **Preview changing an existing label:** Returns the path with the old label replaced by the new one.
- **Preview removing a label (null):** Returns the path without the removed label.
- **Preview on a node deep in the tree with multiple ancestor labels:** Returns the full `'A \u2014 B \u2014 NewLabel'` chain.
- **Preview with empty string (treated as no label):** Returns path without the node's contribution.

**Depends on:** Step 5.

### 7. Create the label editor dialog widget

**File:** `src/lib/screens/repertoire_browser_screen.dart` (private method within the screen state class)

Create a `_showLabelDialog` method that opens an `AlertDialog`.

**Dialog return value contract:** The dialog returns `String?` with the following convention:
- `null` -- user cancelled (no action taken).
- `''` (empty string) -- user explicitly removed the label (save null to DB).
- Any non-empty string -- the new label text (save to DB).

This convention is simple and sufficient since the dialog is private to the screen. It maps cleanly to the DB call: `null` means "do nothing", empty string means "clear the label", non-empty means "set the label".

**Dialog content:**
- **Title:** "Edit label" (or "Add label" if currently unlabeled)
- **Content:**
  - A `TextField` pre-filled with the current label (empty if no label).
  - Below the text field, a live aggregate display name preview. Uses `cache.previewAggregateDisplayName(moveId, currentText)` (from Step 5) to show what the full display name would be if the user saves. If the result is empty, show a placeholder like "(no display name)".
  - The preview updates live as the user types (use a `TextEditingController` with a listener inside a `StatefulBuilder` wrapping the dialog content).
- **Actions:**
  - "Save" -- returns the entered text (trimmed). If the text is empty, returns `''` (empty string, meaning "remove label").
  - "Cancel" -- pops with `null` (dialog dismissed, no action).
  - If the node already has a label, add a "Remove" button that explicitly returns `''` to clear the label.

**Depends on:** Step 5.

### 8. Wire the "Label" button in the browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Replace the stub Label button's `onPressed: null` with a handler `_onEditLabel`:

```dart
TextButton.icon(
  onPressed: selectedId != null ? _onEditLabel : null,
  icon: const Icon(Icons.label, size: 18),
  label: const Text('Label'),
),
```

The button is enabled whenever a node is selected (any node can be labeled). It is disabled when no node is selected (no target for the label).

**Implement `_onEditLabel`:**

```dart
Future<void> _onEditLabel() async {
  final selectedId = _state.selectedMoveId;
  if (selectedId == null) return;
  final cache = _state.treeCache;
  if (cache == null) return;

  final move = cache.movesById[selectedId];
  if (move == null) return;

  final result = await _showLabelDialog(
    context,
    currentLabel: move.label,
    moveId: selectedId,
    cache: cache,
  );

  // null means cancelled -- no action
  if (result == null) return;

  // Normalize: empty string means "remove label" -> save null to DB
  final labelToSave = result.isEmpty ? null : result;

  // No-op guard: skip DB write and cache rebuild if the label is unchanged.
  final currentLabel = move.label;
  if (labelToSave == currentLabel) return;

  final repRepo = LocalRepertoireRepository(widget.db);
  await repRepo.updateMoveLabel(selectedId, labelToSave);
  await _loadData(); // Rebuild cache
}
```

The no-op guard compares the normalized new label to the current label and returns early if they are identical. This avoids an unnecessary DB write and full cache rebuild when the user opens the dialog and saves without making changes.

**Depends on:** Steps 1, 2, 3, 7.

### 9. Write widget tests for label editing

**File:** `src/test/screens/repertoire_browser_screen_test.dart` (extend existing file)

Add a `'Label editing'` test group. Test cases:

- **Label button disabled when no node selected:** Load repertoire, verify Label button `onPressed` is null.
- **Label button enabled when a node is selected:** Select a node, verify Label button `onPressed` is not null.
- **Open label dialog and save a label:** Select an unlabeled node, tap Label, enter text in the dialog, tap Save. Verify the label appears in the tree and the aggregate display name header updates.
- **Open label dialog and clear a label:** Select a labeled node, tap Label, clear the text field, tap Remove/Save. Verify the label is removed from the tree and the display name header updates accordingly.
- **Open label dialog and cancel:** Select a node, tap Label, tap Cancel. Verify no changes were made.
- **Aggregate display name preview in dialog:** Select a node whose ancestor has label "Sicilian", open the label dialog, type "Najdorf". Verify the preview shows "Sicilian \u2014 Najdorf" (em dash).
- **Label persists after reload:** Set a label, navigate away and back (or verify via direct DB query). Verify the label is still present.
- **Label on any node type:** Verify labeling works on a root move, an interior move, a branch point, and a leaf move.
- **No-op guard:** Select a labeled node, open the dialog, save without changing the text. Verify no DB write occurs (e.g., verify cache is not rebuilt, or verify via a spy/counter on the repository call).

**Depends on:** Steps 7, 8.

### 10. Update edit-mode display name preview to reflect labels

**File:** `src/lib/screens/repertoire_browser_screen.dart`

The display name header in `_buildContent` already handles both browse mode and edit mode:

```dart
if (isEditing && _state.lineEntryEngine != null) {
  displayName = _state.lineEntryEngine!.getCurrentDisplayName();
} else {
  displayName = selectedId != null
      ? cache.getAggregateDisplayName(selectedId)
      : '';
}
```

This already works correctly -- `getCurrentDisplayName()` delegates to `cache.getAggregateDisplayName(lastExistingMoveId)`, which picks up labels along the path. No code changes needed here, but verify in testing that the display name preview during edit mode correctly reflects any labels that exist on the existing portion of the path.

**Depends on:** Nothing (verification only).

## Risks / Open Questions

1. **Dialog return value convention.** The dialog uses the convention that `null` means "cancelled", empty string means "remove label", and non-empty string means "set label". This is slightly unconventional but is simple and sufficient for a private dialog method. An alternative is a dedicated sealed result type (`LabelDialogResult.cancelled`, `LabelDialogResult.saved(String?)`), which is more explicit but adds boilerplate. The empty-string convention is sufficient for v0 given the dialog is private to the screen. If the dialog is ever extracted into a shared widget, upgrading to a sealed type would be straightforward.

2. **Separator consistency.** The spec prose and context documents use `" -- "` (double hyphen) as an ASCII approximation of the separator, but the actual implementation in `getAggregateDisplayName` and all existing tests use `" \u2014 "` (em dash, Unicode U+2014). This plan uses the em dash everywhere in code and test expectations. The ASCII double-hyphen in spec prose is treated as informal shorthand.

3. **Label impact warning (deferred).** The spec calls for a warning when labeling a node that has descendants with labels (because the aggregate display names of those descendants will change). This is explicitly deferred to post-v0 in the spec: "Requires subtree traversal and before/after display name computation." The infrastructure to support this is straightforward when needed: use `cache.getSubtree(moveId)` to find descendants, filter for labeled ones, compute before/after display names, and show them in the dialog. But it adds UI complexity (listing affected names) that is not worth the v0 scope.

4. **Transposition conflict warning (deferred).** The spec calls for a warning when labeling a node whose FEN appears elsewhere in the tree with a different label. Also explicitly deferred to post-v0. The infrastructure exists: `cache.getMovesAtPosition(fen)` returns all moves reaching a given FEN. Checking their labels against the new label is trivial. But the UX of the warning (what to show, how to present conflicts across potentially unrelated parts of the tree) needs design thought.

5. **Cache rebuild cost.** After a label update, the entire tree cache is rebuilt via `_loadData()`. For typical repertoires (tens to low hundreds of nodes), this is fast. An alternative is surgical cache update (replace the `RepertoireMove` in `movesById` with a copy that has the new label), but this risks inconsistency and the full-rebuild approach is the established pattern. If performance becomes an issue for very large repertoires, surgical updates can be added later. The no-op guard (Step 8) mitigates the cost for the common case of opening and closing the dialog without changes.

6. **Label during edit mode.** The acceptance criteria says "accessible from browse or edit mode." In v0, the label button is only in the browse-mode action bar. During edit mode, the user is focused on entering moves and the edit-mode action bar has different controls (Take Back, Confirm, Discard, Flip). Adding a label button to the edit-mode action bar is possible but adds clutter. Deferred -- users can exit edit mode, label, and re-enter if needed. The `getCurrentDisplayName()` during edit mode already reflects existing labels on the path.

7. **Label validation.** The spec does not specify constraints on label content (max length, allowed characters, etc.). For v0, labels are free-text strings with no validation beyond trimming whitespace. If the user enters only whitespace, it is treated as "remove label" (empty after trim). Labels with special characters (e.g., em dashes, quotes) are allowed. A max length constraint (e.g., 50 characters) could be added via `TextField.maxLength` for UX but is not specified.

8. **Label uniqueness.** The spec does not require labels to be unique. Multiple nodes can have the same label (e.g., "Main Line" on different branches). The transposition conflict warning (deferred) is about same-FEN-different-label situations, not about label uniqueness.
