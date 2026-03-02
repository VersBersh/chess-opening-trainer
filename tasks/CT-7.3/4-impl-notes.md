# CT-7.3: Implementation Notes

## Files Modified

- **`src/lib/screens/repertoire_browser_screen.dart`** -- Main changes:
  - Removed `isEditMode`, `lineEntryEngine`, `currentFen` fields from `RepertoireBrowserState` and `copyWith`
  - Removed all edit mode event handlers: `_onEnterEditMode`, `_onEditModeMove`, `_onTakeBack`, `_onConfirmLine`, `_onDiscardEdit`, `_showExtensionUndoSnackbar`
  - Removed `_showParityWarningDialog`, `_showDiscardDialog`
  - Removed private instance variables: `_preMoveFen`, `_editModeStartFen`, `_undoGeneration`
  - Removed `_buildEditModeActionBar` method
  - Simplified `PopScope` to just `Scaffold` (no unsaved-edit guard needed)
  - Removed `isEditing` parameter from `_buildContent`, `_buildNarrowContent`, `_buildWideContent`, `_buildDisplayNameHeader`, `_buildChessboard`, `_buildMoveTree`
  - Board always uses `PlayerSide.none` and `onMove: null` (read-only)
  - Board controls always shown (no edit-mode conditional)
  - Tree always passes actual `selectedMoveId` and `_onNodeSelected` (no edit-mode no-op)
  - Replaced Edit and Focus buttons with "Add Line" (`Icons.add`) and "Stats" (`Icons.bar_chart`) in both compact and full-width action bar variants
  - Added `_onAddLine()` handler navigating to `AddLineScreen` with `startingMoveId`, reloading on return
  - Added `_onViewCardStats()` handler that loads card via `getCardForLeaf`, shows dialog with SR stats or snackbar if no card
  - Updated AppBar title to show repertoire name + "Repertoire Manager" subtitle
  - Removed imports: `dartchess`, `line_entry_engine.dart`
  - Added imports: `add_line_screen.dart`

- **`src/test/screens/repertoire_browser_screen_test.dart`** -- Test changes:
  - Removed entire `group('Edit mode', ...)` block (13 tests)
  - Removed entire `group('Extension undo snackbar', ...)` block (3 tests)
  - Removed `'edit-mode display name reflects labels on existing path'` test from Label editing group
  - Updated `'action buttons enabled/disabled state'` test: removed Focus assertions, added Add Line and Stats button assertions
  - Updated `'repertoire name is shown in app bar'` test to also verify "Repertoire Manager" subtitle
  - Added `'board is always PlayerSide.none'` test
  - Added `'no Edit button in action bar'` test
  - Added `'no Focus button in action bar'` test
  - Added `group('Add Line', ...)` with 3 tests: always enabled, navigates with no selection, navigates with startingMoveId
  - Added `group('Card Stats', ...)` with 3 tests: disabled when no leaf, enabled on leaf with dialog, no card shows snackbar
  - Added import for `add_line_screen.dart`

## Deviations from Plan

1. **Date formatting in Card Stats dialog**: Plan did not specify a format. Used ISO-style `YYYY-MM-DD` via manual string formatting instead of `DateFormat` from `intl` package, because `intl` is not a dependency of the project. This avoids adding a new dependency for a single dialog.

2. **Step 6 (screen title) was implemented as part of Step 3**: The AppBar title update was naturally done while simplifying the `build()` method. The plan listed it as a separate step but the implementation location was the same code being modified.

3. **`_buildActionBar` retained as thin delegation wrapper**: Rather than inlining `_buildBrowseModeActionBar` directly, kept `_buildActionBar` as a simple pass-through for consistency with the existing call sites. This can be collapsed in a future cleanup.

4. **`PopScope` removed entirely** rather than simplified to `canPop: true`. Since `canPop: true` with no `onPopInvokedWithResult` is the default behavior, wrapping in `PopScope` adds no value. The Scaffold directly handles the back button.

## Follow-up Work

- Extension undo snackbar tests were removed from this file. The extension/undo logic now lives entirely in `AddLineScreen` / `AddLineController`. Widget tests for extension undo in `AddLineScreen` should be added as part of CT-7.2 follow-up.
- The `_buildActionBar` wrapper method could be inlined since it just delegates to `_buildBrowseModeActionBar`. Low priority cleanup.
