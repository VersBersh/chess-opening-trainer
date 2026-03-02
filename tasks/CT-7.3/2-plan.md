# CT-7.3: Plan

## Goal

Simplify the existing repertoire browser into a read-only Repertoire Manager by removing edit mode and the Focus button, adding an "Add Line" navigation action, implementing "View card stats" for leaf nodes, and updating the screen title.

## Steps

### 1. Remove edit mode state fields from `RepertoireBrowserState`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Remove the following fields from `RepertoireBrowserState`:
- `isEditMode` (bool)
- `lineEntryEngine` (LineEntryEngine?)
- `currentFen` (String?)

Remove the corresponding parameters from the `copyWith` method and constructor.

**Depends on:** Nothing.

### 2. Remove edit mode event handlers and related private state

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Delete the following methods from `_RepertoireBrowserScreenState`:
- `_onEnterEditMode()`
- `_onEditModeMove(NormalMove)`
- `_onTakeBack()`
- `_onConfirmLine()`
- `_onDiscardEdit()`
- `_showExtensionUndoSnackbar()`
- `_showParityWarningDialog()`
- `_showDiscardDialog()`

Remove the private instance variables:
- `_preMoveFen`
- `_editModeStartFen`
- `_undoGeneration`

Remove unused imports (`line_entry_engine.dart`, `package:drift/drift.dart`, and any others that become unused after deletion).

**Depends on:** Step 1.

### 3. Simplify `build()` and `_buildContent()` — remove edit mode branching

**File:** `src/lib/screens/repertoire_browser_screen.dart`

- Simplify `PopScope`: set `canPop: true` always, remove `onPopInvokedWithResult` logic that checked for unsaved edit mode moves.
- In `_buildContent()`: remove the `isEditing` variable and parameter.
- In `_buildNarrowContent()` and `_buildWideContent()`: remove all `isEditing` parameters and conditionals. Board controls always shown, chessboard always `PlayerSide.none`, tree always passes actual `selectedMoveId`, action bar always builds browse mode bar.
- Simplify `_buildChessboard()`: remove `isEditing` parameter, hardcode `playerSide: PlayerSide.none` and `onMove: null`.
- Delete `_buildEditModeActionBar()` entirely.

**Depends on:** Steps 1, 2.

### 4. Update the browse mode action bar — remove Edit and Focus, add "Add Line"

**File:** `src/lib/screens/repertoire_browser_screen.dart`

**Both compact (icon-only) and full-width (TextButton.icon) variants** of the action bar must be updated:

**Remove from both variants:** Edit button and Focus button.

**Add to both variants:** "Add Line" button navigating to `AddLineScreen`:
- Compact variant: `IconButton` with `Icons.add` and tooltip `'Add Line'`.
- Full-width variant: `TextButton.icon` with `Icons.add` icon and `'Add Line'` label.

Handler method:
```dart
void _onAddLine() {
  Navigator.of(context)
      .push(MaterialPageRoute(
        builder: (_) => AddLineScreen(
          db: widget.db,
          repertoireId: widget.repertoireId,
          startingMoveId: _state.selectedMoveId,
        ),
      ))
      .then((_) {
        if (mounted) _loadData();
      });
}
```

This follows the same push-then-reload pattern as the existing Import button.

Add import for `add_line_screen.dart`.

**Retain in both variants:** Import, Label, Delete buttons unchanged.

**Depends on:** Steps 2, 3.

### 5. Implement "View Card Stats" action on leaf nodes

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Add a "Stats" button in **both compact and full-width action bar variants**, enabled when a leaf node is selected:
- Compact variant: `IconButton` with `Icons.bar_chart` (or similar), tooltip `'Stats'`, `onPressed` set to `_onViewCardStats` when `isLeaf` is true, `null` otherwise.
- Full-width variant: `TextButton.icon` with `Icons.bar_chart` icon and `'Stats'` label, same enable logic.

Add `_onViewCardStats()` method that loads the card via `LocalReviewRepository(widget.db).getCardForLeaf(selectedMoveId)` and shows a dialog with: ease factor, interval (days), repetitions, next review date, last quality.

If no card exists, show a snackbar: "No review card for this move."

**Depends on:** Step 4 (needs action bar layout context).

### 6. Update screen title/header

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Update the AppBar title to reflect "Repertoire Manager" purpose -- e.g., add a subtitle "Repertoire Manager" under the repertoire name using a `ListTile` or `Column`.

**Depends on:** Nothing (cosmetic).

### 7. Update tests -- remove edit mode tests, add new tests

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

**Remove:**
- Entire `group('Edit mode', ...)` block
- Entire `group('Extension undo snackbar', ...)` block
- Focus button references in action button tests

**Update:**
- `'action buttons enabled/disabled state'` test: remove Focus assertions, add "Add Line" and Stats button assertions

**Add new tests:**
- Add Line button always present/enabled
- Add Line navigates to AddLineScreen (with `startingMoveId` when node selected)
- Stats button disabled when no leaf selected
- Stats button enabled on leaf node; dialog shows card data
- Stats button on leaf with no card shows snackbar "No review card for this move."
- Board is always `PlayerSide.none`
- No Edit button in action bar
- No Focus button in action bar

**Depends on:** Steps 1-6.

## Risks / Open Questions

1. **View Card Stats is new, not retained.** The acceptance criteria says "remains available" but it's not currently implemented. Plan treats it as a new addition since the spec requires it.

2. **Import button placement.** With Edit/Focus removed and Add Line/Stats added, the action bar has 5 buttons (Add Line, Import, Label, Stats, Delete). The current screen already handles 5 buttons with compact/full-width modes, so this should be fine.

3. **Action bar overflow on narrow screens.** 5 buttons with text labels could be tight. The existing compact (icon-only) mode handles this.

4. **`_loadData()` on return from Add Line.** Full tree rebuild on return. Matches existing Import button behavior; acceptable.

5. **Dead code from edit mode.** After removal, verify no external dependencies on `isEditMode`, `lineEntryEngine`, or `currentFen` fields. These are private to this file, so no external deps expected.

6. **Extension undo test coverage is not lost.** The review flagged that removing `group('Extension undo snackbar', ...)` from the browser tests leaves a gap. However, extension/undo logic was fully moved to `AddLineScreen` and `AddLineController` in CT-7.2. The `AddLineScreen` already implements `_showExtensionUndoSnackbar()` (line 132-165 of `add_line_screen.dart`) and `AddLineController` owns `undoGeneration` and `undoExtension()`. Adding extension/undo widget tests to `add_line_screen_test.dart` is a valid improvement but is **out of scope for CT-7.3** -- it belongs to CT-7.2 follow-up. Removing the browser tests here is correct because the browser no longer has this functionality.

7. **Stats button enabled for any leaf (intentional UX deviation).** The feature spec (`features/repertoire-browser.md` line 100) says View Card Stats is available when the selected node is a leaf "with an associated review card." This plan instead enables the Stats button for **any** leaf and handles the missing-card case at click time with a snackbar ("No review card for this move."). This is an intentional simplification: determining card existence at button-render time would require an extra async query on every node selection, adding latency and complexity for marginal UX benefit. The snackbar approach is clearer and avoids a confusingly disabled button on a leaf the user expects to have a card.
