# CT-9.5 Plan

## Goal

Add a label icon/button to each row in the `MoveTreeWidget` so users can add, edit, or clear labels inline without first selecting the node and using the action bar.

## Steps

### Step 1: Add `onEditLabel` callback to `MoveTreeWidget`

**File:** `src/lib/widgets/move_tree_widget.dart`

Add an optional callback parameter `onEditLabel` of type `void Function(int moveId)?` to `MoveTreeWidget`. This follows the same pattern as the existing `onNodeSelected` and `onNodeToggleExpand` callbacks. Pass it through to each `_MoveTreeNodeTile`.

In `_MoveTreeNodeTile`, add an `onEditLabel` parameter of type `VoidCallback?`.

### Step 2: Add inline label icon to `_MoveTreeNodeTile`

**File:** `src/lib/widgets/move_tree_widget.dart`

In the `_MoveTreeNodeTile.build` method, add a small `IconButton` between the `Expanded` text widget and the due-count badge, within the existing `Row`. Use `Icons.label_outline` as the icon with a small size (e.g., 18-20). The icon should:

- Be tappable independently from the row (its own `onTap` calls `onEditLabel`).
- Have a visual distinction: use `colorScheme.primary` if the node has a label, `colorScheme.onSurfaceVariant` if it does not.
- Use `tooltip: 'Label'` for accessibility.
- Be conditionally enabled: only show/enable when `onEditLabel` is not null.
- Have compact padding for comfortable tap target while staying visually compact. Use `IconButton` with `constraints: BoxConstraints(minWidth: 36, minHeight: 36)` and `padding: EdgeInsets.zero`.

The Row layout becomes: [chevron] [Expanded: move text + label text] [label icon] [due badge].

### Step 3: Wire the callback in `RepertoireBrowserScreen`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Create a new method `_onEditLabelForMove(int moveId)` that is similar to `_onEditLabel()` but takes an explicit `moveId` parameter instead of reading from `_state.selectedMoveId`. Then refactor `_onEditLabel()` to delegate to `_onEditLabelForMove`:

```dart
Future<void> _onEditLabelForMove(int moveId) async {
  final cache = _state.treeCache;
  if (cache == null) return;

  final move = cache.movesById[moveId];
  if (move == null) return;

  final result = await _showLabelDialog(
    context,
    currentLabel: move.label,
    moveId: moveId,
    cache: cache,
  );

  if (result == null) return;

  final labelToSave = result.isEmpty ? null : result;
  if (labelToSave == move.label) return;

  final repRepo = LocalRepertoireRepository(widget.db);
  await repRepo.updateMoveLabel(moveId, labelToSave);
  await _loadData();
}

Future<void> _onEditLabel() async {
  final selectedId = _state.selectedMoveId;
  if (selectedId == null) return;
  await _onEditLabelForMove(selectedId);
}
```

In `_buildMoveTree`, pass `onEditLabel: _onEditLabelForMove` to `MoveTreeWidget`.

### Step 4: Retain the action bar Label button (verify, no change needed)

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Verify that `_buildBrowseModeActionBar` still contains the Label button calling `_onEditLabel`. No code change should be needed — the refactored `_onEditLabel` still works via `selectedMoveId`.

### Step 5: Add widget tests for the inline label icon in `MoveTreeWidget`

**File:** `src/test/widgets/move_tree_widget_test.dart`

Add tests:
1. "each row shows a label icon when onEditLabel is provided" — build a tree with `onEditLabel` set, verify `Icons.label_outline` appears for each visible row.
2. "no label icon when onEditLabel is null" — build a tree without `onEditLabel`, verify no `Icons.label_outline` appears and no label-related `IconButton` is present.
3. "tapping the label icon calls onEditLabel with the correct move ID" — tap the icon, verify callback receives correct move ID.
4. "tapping the row itself does not trigger onEditLabel" — tap row text, verify only `onNodeSelected` fires.
5. "label icon uses primary color when node has a label" — verify icon color.
6. "label icon uses onSurfaceVariant when node has no label" — verify icon color.

### Step 6: Add integration tests for inline label editing on the browser screen

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add tests to the existing `Label editing` group. All tests must find the inline label icon by scoping to the tree row area (e.g., using `find.descendant(of: find.byType(MoveTreeWidget), matching: find.byTooltip('Label'))`) to avoid accidentally hitting the action-bar Label button:

1. "inline label icon on tree row opens label dialog" — ensure no node is selected, tap the inline icon scoped to a specific tree row, verify the label dialog opens. This proves the inline path is independent of selection.
2. "inline label save updates the move's label" — tap the inline icon, enter text, save, verify DB and UI update.
3. "inline label icon works without selecting the node first" — verify that no node is selected before tapping, confirming the core UX improvement.
4. "inline label clear removes the label" — on a labeled node, tap the inline icon, tap Remove, verify label cleared.

### Step 7 (optional): Extract `_showLabelDialog` to a shared utility

**Files:**
- New: `src/lib/widgets/label_dialog.dart`
- Modify: `src/lib/screens/repertoire_browser_screen.dart`
- Modify: `src/lib/screens/add_line_screen.dart`

Extract the duplicated `_showLabelDialog` into a top-level function `showLabelDialog` in a new file. Both screens import and call this shared function. This reduces duplication and ensures future improvements apply everywhere.

## Risks / Open Questions

1. **Tap target collision.** The row has an `InkWell` for selection. An `IconButton` inside should absorb taps naturally. The existing chevron `GestureDetector` already uses this pattern, so there is precedent. Needs testing.

2. **Row width pressure.** Adding a ~36px icon to every row increases horizontal pressure on narrow screens. The `Expanded` widget already handles this via `TextOverflow.ellipsis`, so risk is limited to visual crowding, not layout breakage.

3. **Label dialog scope.** The current `_showLabelDialog` already implements aggregate name preview. The descendant impact warning is deferred to post-v0 per spec. No additional work needed.

4. **Step 7 optionality.** Extracting the shared label dialog expands scope. Can be skipped to keep the diff minimal.

5. **"Line list view" terminology.** The task says "line list view" but no separate flat list view exists. This plan interprets it as the existing tree's node rows in `MoveTreeWidget`. If a separate flat list view is later added, the pattern should be replicated there.
