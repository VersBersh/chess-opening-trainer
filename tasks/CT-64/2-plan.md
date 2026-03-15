# CT-64: Implementation Plan

## Goal

Add a "New Line" reset button to the Add Line screen that appears after a line has been confirmed, allowing the user to clear the board and pills back to the starting position without navigating away.

## Steps

### 1. Add a `_hasConfirmedSinceLastReset` flag and `canResetForNewLine` getter to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a private boolean field `_hasConfirmedSinceLastReset` (initially `false`) to the controller:

```dart
bool _hasConfirmedSinceLastReset = false;
```

Set it to `true` at the end of a successful confirm. Both `_persistMoves()` and `_persistLabelsOnly()` return `ConfirmSuccess` -- set the flag to `true` immediately before those return statements (after the `_loadData` call succeeds). Also set it in `flipAndConfirm()` along the same path.

Clear it to `false` in `_loadData()` when NOT called from a confirm path. The simplest approach: clear it at the top of the public `loadData()` method (which is the entry point for initial load, undo, and the new `resetForNewLine()`). The internal `_loadData()` calls from `_persistMoves` / `_persistLabelsOnly` do NOT go through `loadData()`, so they will not clear it.

Add a computed property:

```dart
/// Whether the "New Line" reset action is available.
///
/// True only after a successful confirm in the current session. Cleared
/// on initial load, undo, or when the user taps "New Line" to reset.
bool get canResetForNewLine => _hasConfirmedSinceLastReset;
```

**Why not use `isExistingLine`:** `isExistingLine` is true whenever the user follows existing saved moves with no new buffered moves (e.g. after `loadData` with a `startingMoveId`, or after simply navigating existing pills). It does not distinguish "the user just confirmed" from "the user is just browsing." A dedicated flag avoids exposing the reset action in non-post-confirm scenarios.

### 2. Add `resetForNewLine()` method to `AddLineController`

**File:** `src/lib/controllers/add_line_controller.dart`

Add a new public method:

```dart
/// Resets the screen for a new line entry.
///
/// Invalidates any pending undo snackbar and reloads to the starting
/// position, preserving the repertoire and board orientation.
Future<void> resetForNewLine() async {
  _undoGeneration++;
  await loadData();
}
```

This calls the public `loadData()`, which clears `_hasConfirmedSinceLastReset` (per Step 1), clears `_pendingLabels`, rebuilds the engine from `_startingMoveId`, resets pills, FEN, focus, and display name. Board orientation is preserved because `_loadData()` carries `_state.boardOrientation` forward.

The `_undoGeneration++` before `loadData()` invalidates any active undo snackbar so a stale "Undo" action cannot fire after reset.

### 3. Add "New Line" button to the screen's action bar (conditionally rendered)

**File:** `src/lib/screens/add_line_screen.dart`

**3a.** Add a `_onNewLine()` handler method in `_AddLineScreenState`:

```dart
Future<void> _onNewLine() async {
  setState(() {
    _isLabelEditorVisible = false;
    _parityWarning = null;
  });
  _localMessengerKey.currentState?.clearSnackBars();
  await _controller.resetForNewLine();
  if (mounted) {
    _boardController.resetToInitial();
    // If the controller's starting position is not the initial FEN,
    // sync the board to it.
    final fen = _controller.state.currentFen;
    if (fen != kInitialFEN) {
      _boardController.setPosition(fen);
    }
  }
}
```

This clears transient UI state (`_isLabelEditorVisible`, `_parityWarning`) before resetting, matching the pattern in `_onTakeBack()`. It also clears snackbars, calls the controller reset, and syncs the board widget.

**3b.** Conditionally render the "New Line" button in `_buildActionBar()`. Insert it after the Confirm button, wrapped in an `if`:

```dart
// New Line -- only shown after a successful confirm
if (_controller.canResetForNewLine)
  TextButton.icon(
    onPressed: _onNewLine,
    icon: const Icon(Icons.add, size: 18),
    label: const Text('New Line'),
  ),
```

The button is only rendered when `canResetForNewLine` is true (post-confirm). When rendered, it is always enabled (there is no disabled state for this button -- if it's visible, tapping it resets). This avoids showing a disabled "New Line" button to users who have not yet confirmed anything.

### 4. Add unit tests for `resetForNewLine()` and `canResetForNewLine` in controller tests

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a test group `'Reset for new line'` with the following tests:

**4a.** `'canResetForNewLine is false on initial load'`:
- Seed a repertoire, create controller, load data.
- Assert `canResetForNewLine` is false.

**4b.** `'canResetForNewLine is false when merely following an existing line'`:
- Seed a repertoire with existing moves (e.g. `['e4', 'e5', 'Nf3']`).
- Create controller, load data, follow all existing moves via `onBoardMove`.
- Assert `isExistingLine` is true (existing behavior), but `canResetForNewLine` is false.
- This verifies the distinction between `isExistingLine` and the new flag.

**4c.** `'canResetForNewLine is false when loading with startingMoveId'`:
- Seed a repertoire with existing moves.
- Create controller with `startingMoveId` set to a mid-tree move.
- Load data.
- Assert `canResetForNewLine` is false (even though `isExistingLine` is true).

**4d.** `'canResetForNewLine is false before confirm and true after'`:
- Play moves (unsaved) -> assert `canResetForNewLine` is false.
- Confirm -> assert `canResetForNewLine` is true.

**4e.** `'resetForNewLine clears pills and returns to starting position'`:
- Seed a repertoire, create controller, load data, play moves, confirm them.
- Verify post-confirm state: pills present, `canResetForNewLine` true.
- Call `resetForNewLine()`.
- Assert: pills are empty (if `_startingMoveId` is null) or show only the existing path to `_startingMoveId`, `hasNewMoves` is false, `currentFen` is `kInitialFEN` (or the starting move's FEN), `canResetForNewLine` is false (flag cleared by reset).

**4f.** `'resetForNewLine increments undoGeneration'`:
- Confirm a line, capture `undoGeneration`.
- Call `resetForNewLine()`.
- Assert `undoGeneration` is greater than the captured value.

**4g.** `'resetForNewLine preserves board orientation'`:
- Flip board, confirm a line, call `resetForNewLine()`.
- Assert `state.boardOrientation` remains unchanged.

**4h.** `'canResetForNewLine is cleared by undo'`:
- Confirm a line -> `canResetForNewLine` is true.
- Call `undoNewLine()` (which calls `loadData()` internally).
- Assert `canResetForNewLine` is false.

### 5. Add widget tests for the "New Line" button

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests in the existing `'AddLineScreen'` group:

**5a.** `'New Line button not shown when no confirmed line'`:
- Pump screen with empty repertoire.
- Assert no widget with text "New Line" exists in the tree.

**5b.** `'New Line button not shown when merely following an existing line'`:
- Seed a repertoire with existing moves. Pump screen.
- Follow all existing moves on the board (programmatically).
- Assert `isExistingLine` is true on the controller, but no "New Line" button is rendered.
- This is the key test that distinguishes the post-confirm flag from `isExistingLine`.

**5c.** `'New Line button shown and enabled after confirming a line'`:
- Use `pumpWithNewLine()` helper, tap Confirm, dismiss the no-name warning dialog.
- After `pumpAndSettle()`, assert a "New Line" button exists and is enabled.

**5d.** `'Tapping New Line resets board and pills to starting position'`:
- Confirm a line (e.g., e4).
- Verify pills show the confirmed line.
- Tap "New Line".
- After `pumpAndSettle()`, assert:
  - Pills are empty (back to initial position for a root-level start).
  - The "Existing line" info text is gone.
  - The board is at the initial FEN.
  - Confirm button is disabled.
  - The "New Line" button is no longer rendered (post-confirm flag cleared).

**5e.** `'New Line preserves repertoire and board orientation'`:
- Flip board, confirm a line, tap "New Line".
- Assert board orientation is still black.

**5f.** `'New Line clears active snackbar'`:
- Confirm a line (snackbar "Line saved" appears).
- Tap "New Line".
- Assert snackbar is gone.

**5g.** `'New Line clears label editor and parity warning'`:
- Confirm a line, open label editor (tap a pill twice), then tap "New Line".
- Assert `_isLabelEditorVisible` is false (label editor not rendered).

## Risks / Open Questions

1. **Action bar width on narrow screens:** Adding a conditional fifth button ("New Line") to the action bar row may cause overflow on very narrow screens when it appears. The existing bar already has four buttons (Flip, Take Back, Confirm, Label). Mitigation: use a compact label ("New Line" is 8 characters, similar to "Take Back"). The button only appears in post-confirm state, where Take Back and Confirm are both disabled, so visual weight is redistributed. If overflow is observed, consider moving the button to the app bar actions area (as an `IconButton`) or using a `SingleChildScrollView` wrapper on the action bar row.

2. **Starting from a `startingMoveId`:** When the screen is opened with a `startingMoveId` (branching from an existing position), `resetForNewLine()` resets to that same starting position -- not to the absolute root. This seems correct (the user stays in the same context), but the acceptance criterion says "clears the board position" which could be interpreted as going back to the root. The `loadData()` behavior (resetting to `_startingMoveId`) is consistent with how undo works today and preserves the "same context" requirement.

3. **Conditional rendering vs. always-visible-but-disabled:** The review flagged that the original plan showed the button always visible but disabled, contrary to the goal ("appears after a line has been confirmed"). The revised plan conditionally renders the button only in post-confirm state. While the existing Flip/Take Back/Confirm/Label buttons follow an always-visible-but-disabled pattern, those are core editing actions that are always conceptually applicable. The "New Line" button is a workflow action that has no meaning before a confirm has occurred, so conditional rendering better matches user expectations and avoids a permanently disabled button that adds visual noise.

4. **Review Issue 2 nuance (conditional render vs. disabled):** The existing action bar pattern does show all buttons always and disables them. The review's recommendation to conditionally render is adopted here because the "New Line" button is qualitatively different -- it is a post-workflow action, not an editing primitive. If the team prefers consistency with the existing pattern (always visible, disabled), the `canResetForNewLine` getter still provides the correct enablement logic, and the only change needed is replacing the `if` wrapper with a ternary on `onPressed`.
