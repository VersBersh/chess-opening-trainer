# CT-2.10: Plan

## Goal

Show a warning dialog with before/after display name previews when labeling a node that has descendants with their own labels, allowing the user to confirm or cancel.

## Steps

### 1. Add `LabelImpactEntry` class and `getDescendantLabelImpact` method to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

Add a simple data class `LabelImpactEntry` with fields `moveId`, `before` (String), `after` (String).

Add method `getDescendantLabelImpact(int moveId, String? newLabel)` to `RepertoireTreeCache`:
- Call `getSubtree(moveId)` to get all descendants.
- Filter to descendants (skip moveId itself) that have a non-null label.
- For each, compute "before" via `getAggregateDisplayName(descendant.id)`.
- For "after", walk root-to-descendant path (using `getLine`), concatenate labels but substitute `newLabel` for the label at `moveId`. This is a private helper `_previewDescendantDisplayName(descendantMoveId, changedMoveId, newLabel)`.
- Only include entries where before != after.
- Return `List<LabelImpactEntry>`.

**Depends on:** Nothing.

### 2. Write unit tests for `getDescendantLabelImpact`

**File:** `src/test/models/repertoire_tree_cache_test.dart`

Add test group `'getDescendantLabelImpact'` with cases:
- No labeled descendants -> empty list
- One labeled descendant -> one entry with correct before/after
- Multiple labeled descendants at different depths -> all reported
- Changing an existing label -> before/after reflect the change
- Removing a label (null) -> descendants lose the removed segment
- No-op (same label) -> empty list (before == after)
- Unlabeled descendants not included

**Depends on:** Step 1.

### 3. Add `LabelChangeCancelledException` and `showLabelImpactWarningDialog` to `repertoire_dialogs.dart`

**File:** `src/lib/widgets/repertoire_dialogs.dart`

Add an import for `LabelImpactEntry` from `../models/repertoire.dart`.

Define `LabelChangeCancelledException` as a simple class in this file. This exception is a UI flow-control concern (used to signal that the user cancelled a dialog, causing `InlineLabelEditor._confirmEdit()` to keep the editor open). It belongs alongside the dialog functions that trigger it, not in the data layer.

```dart
/// Thrown when the user cancels a label change from the impact warning dialog.
/// Caught by [InlineLabelEditor._confirmEdit] to keep the editor open.
class LabelChangeCancelledException implements Exception {}
```

Add dialog function following existing pattern:

```dart
Future<bool?> showLabelImpactWarningDialog(
  BuildContext context, {
  required List<LabelImpactEntry> affectedEntries,
})
```

Dialog content:
- **Title:** "Label affects other names"
- **Content:** Scrollable list of affected entries. Each entry shows the "before" name (dimmed/strikethrough) and "after" name (normal). Wrap in `ConstrainedBox` with max height for many entries.
- **Actions:** "Cancel" (returns false), "Apply" (returns true)

Follow `showBranchDeleteConfirmationDialog` pattern for structure and styling.

**Depends on:** Step 1 (for `LabelImpactEntry` type).

### 4. Wrap `onSave` in `RepertoireBrowserScreen._buildInlineLabelEditor()`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

This file already imports `repertoire_dialogs.dart` (line 13). Add an import for `LabelImpactEntry` from `../models/repertoire.dart` if not already transitively available.

Change the `onSave` callback at line 234 from:
```dart
onSave: (label) => _controller.editLabel(moveId, label),
```
to:
```dart
onSave: (label) async {
  final impact = cache.getDescendantLabelImpact(moveId, label);
  if (impact.isNotEmpty) {
    final confirmed = await showLabelImpactWarningDialog(
      context,
      affectedEntries: impact,
    );
    if (confirmed != true) {
      throw LabelChangeCancelledException();
    }
  }
  await _controller.editLabel(moveId, label);
},
```

Throwing an exception when cancelled leverages the existing `InlineLabelEditor._confirmEdit()` catch block — the editor stays open, text field re-enables, user can retry or dismiss. This requires no changes to the `InlineLabelEditor` widget.

**Depends on:** Steps 1, 3.

### 5. Wrap `onSave` in `AddLineScreen._buildInlineLabelEditor()`

**File:** `src/lib/screens/add_line_screen.dart`

This file currently does not import `repertoire_dialogs.dart` or the exception class. Add these two imports:
```dart
import '../widgets/repertoire_dialogs.dart';
import '../models/repertoire.dart';
```
(The `repertoire.dart` import is needed for `LabelImpactEntry` if it is not re-exported by another already-imported file. The `repertoire_dialogs.dart` import is needed for `showLabelImpactWarningDialog` and `LabelChangeCancelledException`.)

Same pattern as step 4. Change line 376 from:
```dart
onSave: (label) => _controller.updateLabel(focusedIndex, label),
```
to:
```dart
onSave: (label) async {
  final move = _controller.getMoveAtPillIndex(focusedIndex);
  if (move != null && cache != null) {
    final impact = cache!.getDescendantLabelImpact(move.id, label);
    if (impact.isNotEmpty) {
      final confirmed = await showLabelImpactWarningDialog(
        context,
        affectedEntries: impact,
      );
      if (confirmed != true) {
        throw LabelChangeCancelledException();
      }
    }
  }
  await _controller.updateLabel(focusedIndex, label);
},
```

Note: `cache` is already available as `state.treeCache` in this method's scope (assigned at line 366). The `move` and `cache` null-checks at lines 361-367 guard the early returns, but inside the `onSave` closure we must re-check because the closure captures the outer variable. Use `cache!` since we know the outer method already returned if cache was null.

**Depends on:** Steps 1, 3.

### 6. Write widget tests for the warning dialog

**File:** `src/test/widgets/repertoire_dialogs_test.dart` (new or extend existing)

Test cases:
- Dialog displays before/after names for each entry
- Cancel button returns false
- Apply button returns true
- Many entries render in scrollable container without overflow

**Depends on:** Step 3.

### 7. Write integration tests for the save-with-warning flow

**Files:**
- `src/test/screens/repertoire_browser_screen_test.dart` (extend existing)
- `src/test/screens/add_line_screen_test.dart` (extend existing)

#### 7a. Repertoire Browser tests

Add to `src/test/screens/repertoire_browser_screen_test.dart`:
- No warning when no labeled descendants -> label saved directly
- Warning shown when labeled descendants exist -> correct before/after names displayed
- Confirm (Apply) -> label saved
- Cancel -> label NOT saved, editor stays open

#### 7b. Add Line tests

Add to `src/test/screens/add_line_screen_test.dart`. This file already has extensive label-editing coverage (inline editor open/close, multi-line warning, Enter-to-persist, dismiss-without-save). Add analogous warning-flow tests:
- No warning when no labeled descendants -> label saved directly
- Warning shown when labeled descendants exist -> correct before/after names displayed
- Confirm (Apply) -> label saved
- Cancel -> label NOT saved, editor stays open

**Depends on:** Steps 4, 5.

## Risks / Open Questions

1. **Exception-based cancellation**: Throwing `LabelChangeCancelledException` from `onSave` when the user cancels is unidiomatic but leverages the existing catch-all in `_confirmEdit()`. The editor stays open, which is the correct UX. The alternative (changing `onSave` to return `Future<bool>`) would require modifying `InlineLabelEditor`'s interface and all callers. The exception approach is simpler and contained.

2. **Exception placement in `repertoire_dialogs.dart`**: The review suggested keeping `LabelChangeCancelledException` out of `repertoire.dart` (data layer) since it is a UI flow-control concern. This is correct — the exception is defined in `repertoire_dialogs.dart` alongside the dialog function that triggers the cancellation. Both screens import this file to access the dialog and the exception together.

3. **Unlabeled descendants not reported**: Descendants without their own labels are not included in the warning, even though their inherited display name changes. This is per-spec — only descendants with labels have visible display names that would change.

4. **Large subtrees**: For nodes near the root with many labeled descendants, the dialog could be long. The scrollable container with max height handles this. A "and N more" truncation could be added later if needed.

5. **Dialog context**: The `showLabelImpactWarningDialog` is called from within the `onSave` callback, which runs during `_confirmEdit()`. The `BuildContext` from the screen's `build` method is used. This should be fine since the screen is still mounted — but if async gaps cause issues, the `mounted` check before proceeding would be needed.
