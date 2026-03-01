# CT-2.2 Implementation Review

## Verdict

**Approved with Notes**

The implementation faithfully follows the plan across all 11 steps. The `LineEntryEngine` service is cleanly separated, the browser screen edit mode is well-structured, and both persistence paths (extension vs. branching) are handled correctly. The issues found are minor.

## Progress

- [x] **Step 1: Create `LineEntryEngine`** -- Fully implemented. `BufferedMove`, result types (`MoveAcceptResult`, `TakeBackResult`, `ParityValidationResult`, `ConfirmData`), and all specified methods (`acceptMove`, `canTakeBack`, `takeBack`, `totalPly`, `validateParity`, `hasNewMoves`, `getConfirmData`, `getCurrentDisplayName`) are present and match the plan.
- [x] **Step 2: Unit tests for `LineEntryEngine`** -- All 16 specified test cases are covered: follow existing branch, diverge, buffer multiple, start from mid-tree, start from root, take-back (3 moves), take-back at boundary, parity match/mismatch/even, getConfirmData (isExtension true/false, null parentMoveId, sortOrder x3), hasNewMoves, empty line entry. Additional tests for `totalPly`, `getCurrentDisplayName`, and take-back to initial position are present.
- [x] **Step 3: Add edit mode state to `RepertoireBrowserState`** -- `isEditMode`, `lineEntryEngine`, `currentFen` fields added with nullable function wrapper `copyWith` pattern matching the existing `selectedMoveId` pattern.
- [x] **Step 4: Edit mode toggle and board interaction** -- `_onEnterEditMode`, `_onEditModeMove` (with `makeSan` destructuring), `_preMoveFen` tracking, `PlayerSide.both` when editing, `PlayerSide.none` when browsing. Navigation buttons hidden during edit mode.
- [x] **Step 5: Edit-mode action bar** -- `_buildActionBar` splits into `_buildBrowseModeActionBar` and `_buildEditModeActionBar`. Flip, Take Back (conditionally enabled), Confirm (conditionally enabled), and Discard buttons present. Display name shown via `getCurrentDisplayName` during edit mode.
- [x] **Step 6: Confirm flow with parity validation and persistence** -- Parity validation with dialog, both Path A (extension via `extendLine`) and Path B (branching via individual `saveMove` + card creation) implemented. Sort order from `getConfirmData`. Null `parentMoveId` handled. Tree cache rebuilt via `_loadData()`.
- [x] **Step 7: Parity warning dialog** -- `_showParityWarningDialog` implemented with correct title, content, and "Flip and confirm" / "Cancel" actions.
- [x] **Step 8: Handle discard on exit without confirm** -- `PopScope` wraps `Scaffold` with `canPop` logic and `onPopInvokedWithResult` showing discard dialog.
- [x] **Step 9: Handle entering edit mode from a specific position** -- `_onEnterEditMode` passes `_state.selectedMoveId` to the engine constructor. Board set to selected node's FEN or initial position.
- [x] **Step 10: Widget tests for edit mode** -- 13 widget tests added: enter edit mode, board interactivity, confirm disabled, take-back disabled, discard exits, navigation hidden, flip board, enter from selected node, enter from root, empty tree, discard restores position, tree selection disabled, confirm infrastructure, edit button always enabled. Move simulation tests reasonably deferred per implementation notes.
- [x] **Step 11: SAN computation unit tests** -- 6 tests in `line_entry_engine_test.dart`: standard move (e4), knight move (Nf3), capture (exd5), promotion (a8=Q), and two check-related tests.

## Issues

### 1. [Minor] `_onDiscardEdit` calls `_boardController._onDiscardEdit` without `setState` call wrapping the position reset

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 400-415

The `_onDiscardEdit` method calls `_boardController.setPosition(...)` outside of `setState`. Since `_boardController` is a `ChangeNotifier` and the `ChessboardWidget` listens to it directly (via `addListener` in its `initState`), this works correctly -- the board will rebuild when `setPosition` calls `notifyListeners`. The subsequent `setState` for `_state` updates the action bar and other state. So this is not actually a bug, but worth noting for clarity that the board update and state update happen through different notification paths. **No fix needed.**

### 2. [Minor] `_onConfirmLine` parity flip doesn't call `setState`

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 335-338

When parity mismatch is detected and the user chooses "Flip and confirm", the board orientation is flipped via:
```dart
_state = _state.copyWith(
  boardOrientation: _state.boardOrientation == Side.white
      ? Side.black : Side.white,
);
```
This mutates `_state` without calling `setState`, so the UI won't reflect the flipped board orientation until the subsequent `_loadData()` / `setState` at the end of the confirm flow. Since the confirm flow immediately proceeds to persistence and reload (which does call `setState`), the user will see the flip after the confirm completes. This is acceptable behavior -- the visual flip happens at the same time as the mode transition. However, if persistence is slow, there could be a brief moment where the board hasn't visually flipped. **Suggested improvement:** Wrap in `setState` for immediate visual feedback, or accept as-is since the flip is immediately followed by mode exit.

### 3. [Minor] `hasDiverged` is not reset after full buffer clear via `takeBack`

**File:** `src/lib/services/line_entry_engine.dart`, line 101

Once `hasDiverged` is set to `true`, it remains true even after all buffered moves are taken back. This means if the user:
1. Follows existing moves to node X
2. Plays a new move (diverges, `hasDiverged = true`)
3. Takes back the new move (buffer empty, but `hasDiverged` still true)
4. Plays a move that exists as a child of X

...the move at step 4 will be buffered rather than followed. This is a design decision, not a bug. The plan does not explicitly address this edge case, but the behavior is consistent with a "one-way" flow model. The user can discard and re-enter edit mode if they want to restart. **No fix needed** unless the product spec requires following existing branches after take-back.

### 4. [Minor] Bb5 check test is inaccurate but self-correcting

**File:** `src/test/services/line_entry_engine_test.dart`, lines 657-669

The test titled "check: Bb5+ in Ruy Lopez produces SAN with + suffix" actually verifies that `Bb5` does NOT produce a `+` suffix (because Bb5 in the Ruy Lopez is not check). The comment on line 667 acknowledges this. A separate test on lines 671-685 correctly tests an actual check scenario (`Qxf7+`). The test title is misleading but the assertions are correct. **Suggested fix:** Rename the test to something like "Bb5 in Ruy Lopez without check" to avoid confusion.

### 5. [Minor] Double `setState` in confirm flow

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 388-398

After `_loadData()` (which calls `setState` internally at line 160), the confirm flow calls `setState` again to clear edit mode fields. This causes two rebuilds in quick succession. A minor optimization would be to merge these by having `_loadData` accept additional state updates, or by clearing edit mode fields before calling `_loadData`. **No functional impact.**

### 6. [Minor] `_loadData` does not set `isLoading: true` at start

**File:** `src/lib/screens/repertoire_browser_screen.dart`, line 128

On initial load, `isLoading` defaults to `true` in the constructor, so the loading indicator shows correctly. However, when `_loadData` is called again during the confirm flow, `isLoading` remains `false` throughout the reload. This means the user sees the old tree data until the reload completes. For a quick DB operation this is fine, but for consistency, setting `isLoading: true` at the start of `_loadData` would show a brief loading indicator during reload. **Pre-existing pattern, not introduced by this change.**

### 7. [Minor] `_editModeStartFen` field is unplanned but justified

**File:** `src/lib/screens/repertoire_browser_screen.dart`, line 111

The `_editModeStartFen` field is not in the plan but is documented in the implementation notes as deviation #2. It is used by `_onDiscardEdit` to restore the board position when discarding. This is a reasonable addition -- the plan's Step 5b mentions "Reset board to the position before edit mode started" but did not explicitly name a field for it. **Justified deviation.**

### 8. [Minor] Tree node taps during edit mode use no-op callback `(_) {}`

**File:** `src/lib/screens/repertoire_browser_screen.dart`, line 592

During edit mode, `onNodeSelected` is set to `(_) {}` (a no-op). This means tapping a tree node fires the callback but does nothing. An alternative would be setting `onNodeSelected` to `null`, but this would depend on how `MoveTreeWidget` handles null callbacks (whether it makes nodes non-tappable). The current approach is safe and correct -- taps are absorbed without effect. The widget test on line 677 verifies this behavior. **No fix needed.**
