# CT-2.11: Transposition Conflict Warning — Plan

## Goal

When a user labels a move, check if the same FEN position exists elsewhere in the tree with a different label and show an advisory warning dialog before persisting.

## Steps

### 1. Add a conflict detection helper method to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

Add a method `findLabelConflicts(int moveId, String? newLabel)` that:
- Returns an empty list immediately when `newLabel` is null (clearing a label is never a conflict).
- Looks up the move by ID to get its FEN.
- Calls `getMovesAtPosition(fen)` to find all moves reaching the same position.
- Filters out the move itself (by ID).
- Filters to moves that have a non-null label that differs from `newLabel`.
- Returns a list of conflicting moves (or an empty list if no conflicts).

This keeps the detection logic in the cache where the data lives, and makes it easily testable without UI.

```dart
/// Returns moves at the same FEN position that have a different label
/// than [newLabel]. Excludes the move [moveId] itself.
/// Returns an empty list when [newLabel] is null (label removal is not
/// a conflict).
List<RepertoireMove> findLabelConflicts(int moveId, String? newLabel) {
  if (newLabel == null) return [];
  final move = movesById[moveId];
  if (move == null) return [];
  final siblings = getMovesAtPosition(move.fen);
  return siblings.where((m) =>
    m.id != moveId &&
    m.label != null &&
    m.label != newLabel
  ).toList();
}
```

### 2. Add a transposition conflict warning dialog in a new dedicated file

**File:** `src/lib/widgets/label_conflict_dialog.dart` (new file)

Create a new file containing both the `ConflictInfo` data class and the `showTranspositionConflictDialog` free function. This avoids coupling issues: `repertoire_dialogs.dart` currently imports `repertoire_browser_controller.dart` for `OrphanChoice`, so any screen importing it would inherit a transitive dependency on the browser controller. A dedicated file keeps the dialog and its data type self-contained and importable by both AddLine and Browser screens without pulling in unrelated controller types.

```dart
import 'package:flutter/material.dart';

/// Lightweight data class describing a single label conflict for display.
class ConflictInfo {
  final String label;
  final String path;
  const ConflictInfo({required this.label, required this.path});
}

Future<bool?> showTranspositionConflictDialog(
  BuildContext context, {
  required String? newLabel,
  required List<ConflictInfo> conflicts,
})
```

The dialog should:
- Title: "Label conflict"
- Body: "This position appears elsewhere in your repertoire with a different label:" followed by a list of conflicting labels and their move paths.
- Actions: "Cancel" (returns `false`) and "Apply anyway" (returns `true`).

### 3. Add a helper method to build conflict display info

**File:** `src/lib/models/repertoire.dart`

Add a method to `RepertoireTreeCache` that, given a list of conflicting `RepertoireMove` objects, produces human-readable path descriptions. This leverages the existing `getLine()` and `getMoveNotation()` methods.

```dart
/// Returns a human-readable path string for a move, e.g. "1. e4 1...c5 2. Nf3".
String getPathDescription(int moveId) {
  final line = getLine(moveId);
  final parts = <String>[];
  for (var i = 0; i < line.length; i++) {
    parts.add(getMoveNotation(line[i].id, plyCount: i + 1));
  }
  return parts.join(' ');
}
```

### 4. Integrate the warning into `InlineLabelEditor` via a new callback

**File:** `src/lib/widgets/inline_label_editor.dart`

Add an optional callback parameter to `InlineLabelEditor`:

```dart
final Future<bool> Function(String? newLabel)? onCheckConflicts;
```

In `_confirmEdit()`, after computing `labelToSave` and before calling `widget.onSave(labelToSave)`:
- If `labelToSave` is null (user is clearing the label), skip the conflict check entirely and proceed to save.
- Otherwise, if `onCheckConflicts` is non-null, call it:

```dart
if (labelToSave != null && widget.onCheckConflicts != null) {
  final proceed = await widget.onCheckConflicts!(labelToSave);
  if (!proceed) {
    // User cancelled — keep editor open.
    if (mounted) setState(() => _isSaving = false);
    return;
  }
}
```

This keeps `InlineLabelEditor` unaware of the specifics — the caller decides what "check conflicts" means. The null-label guard here is a belt-and-suspenders defense complementing the guard in `findLabelConflicts` (Step 1), ensuring the dialog is never shown when clearing a label even if a caller forgets the model-level guard.

### 5. Wire up the conflict check in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

Add an import for `label_conflict_dialog.dart`. In `_buildInlineLabelEditor()`, pass the `onCheckConflicts` callback:

```dart
onCheckConflicts: (newLabel) async {
  final cache = state.treeCache;
  if (cache == null) return true;
  final conflicts = cache.findLabelConflicts(move.id, newLabel);
  if (conflicts.isEmpty) return true;

  final conflictInfos = conflicts.map((c) => ConflictInfo(
    label: c.label!,
    path: cache.getPathDescription(c.id),
  )).toList();

  final result = await showTranspositionConflictDialog(
    context,
    newLabel: newLabel,
    conflicts: conflictInfos,
  );
  return result == true;
},
```

### 6. Wire up the conflict check in `RepertoireBrowserScreen`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Add an import for `label_conflict_dialog.dart`. In `_buildInlineLabelEditor()`, pass the same `onCheckConflicts` callback, using the same pattern as step 5. The only difference is the move ID source (`moveId` local variable vs `move.id`).

### 7. Write unit tests for `findLabelConflicts`

**File:** `src/test/models/repertoire_tree_cache_test.dart` (or add to an existing test file for RepertoireTreeCache)

Test cases:
- No conflicts when no other moves share the FEN.
- No conflicts when other moves at the same FEN have the same label.
- No conflicts when other moves at the same FEN have null labels.
- Conflicts detected when another move at the same FEN has a different non-null label.
- The move itself is excluded from results even if it has a different label (edge case: changing label).
- Multiple conflicts returned when multiple moves at the same FEN have different labels.
- Returns empty list when `newLabel` is null (clearing a label), even when other moves at the same FEN have labels.

### 8. Write widget/integration tests for the dialog flow in both screens

Tests must cover both AddLine and Browser screens since the feature is wired into both.

**File:** `src/test/screens/add_line_screen_test.dart`

Add a test group for transposition conflict warnings:
- Label save proceeds without dialog when no conflicts exist.
- Dialog is shown when conflicts exist; user taps "Apply anyway" -> label is saved.
- Dialog is shown when conflicts exist; user taps "Cancel" -> label is not saved, editor stays open.
- Clearing a label (empty text -> null) does NOT show the dialog even when other transpositions have labels.

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add a test group for transposition conflict warnings (parallel to AddLine):
- Label save proceeds without dialog when no conflicts exist.
- Dialog is shown when conflicts exist; user confirms -> label is saved.
- Dialog is shown when conflicts exist; user cancels -> label is not saved, editor stays open.
- Clearing a label does NOT show the dialog even when other transpositions have labels.

Both test files already have `seedRepertoire` helpers that accept `labelsOnSan` and `lines` parameters, which can create transposition scenarios (e.g., two lines reaching the same FEN via different move orders, with one already labeled).

## Risks / Open Questions

1. **FEN matching granularity:** The spec says "same FEN position." The cache has both `movesByFen` (exact FEN) and `movesByPositionKey` (normalized, ignoring halfmove/fullmove clocks). Using exact FEN (`getMovesAtPosition`) is the conservative choice and matches the spec. However, two positions that differ only in halfmove clock are arguably the same position for labeling purposes. Consider using `movesByPositionKey` for a broader match. **Recommendation:** Start with exact FEN via `getMovesAtPosition()` for simplicity. If users report missed conflicts due to halfmove clock differences, switch to `movesByPositionKey` later.

2. **Cross-repertoire conflicts:** The current `RepertoireTreeCache` is scoped to a single repertoire. Conflicts are only detected within the same repertoire. This seems correct — different repertoires are independent namespaces. No action needed, but worth noting.

3. **Conflict during line entry (unsaved moves):** The `InlineLabelEditor` is only available on saved pills in the AddLine screen (the `canEditLabel` guard requires `isSavedPillFocused && !_controller.hasNewMoves`). So the tree cache will always have the relevant move when the editor is shown. No special handling needed for buffered moves.

4. **Label removal (clearing to null):** Clearing a label is explicitly excluded from conflict checks at two levels: `findLabelConflicts` returns early when `newLabel` is null (Step 1), and `InlineLabelEditor._confirmEdit` skips the `onCheckConflicts` callback when `labelToSave` is null (Step 4). This matches the spec intent — the warning is about assigning a conflicting label, not about removing one.

5. **Path description readability:** For long lines, the full path description (e.g., "1. e4 1...c5 2. Nf3 2...d6 3. d4 3...cxd4 4. Nxd4") could be verbose. Consider truncating to the last N moves or showing only the conflicting move's label and the aggregate display name of its path. The aggregate display name is likely more useful — e.g., "Sicilian -- Kan" rather than the full move sequence. **Recommendation:** Show the aggregate display name if it exists; fall back to the move path if no labels exist along the conflicting move's path.

6. **Review Issue 3 — Dialog file placement rationale:** The review flagged that `repertoire_dialogs.dart` imports `repertoire_browser_controller.dart` (for `OrphanChoice`), so having AddLineScreen import that file would create an unnecessary transitive dependency on browser-controller types. This is correct — verified in the codebase: `repertoire_dialogs.dart` line 3 imports `../controllers/repertoire_browser_controller.dart`. The solution (Step 2) uses a dedicated `label_conflict_dialog.dart` file that is self-contained, keeping `ConflictInfo` and the dialog function together with no controller imports. An alternative would be to refactor `OrphanChoice` out of the browser controller into a shared types file, but that is out of scope for this ticket and not needed since the new dialog has its own file.
