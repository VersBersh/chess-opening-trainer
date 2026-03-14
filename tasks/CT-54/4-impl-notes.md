# CT-54: Implementation Notes

## Files modified

### `features/add-line.md`
- **Entry Flow section:** Added step 7 documenting post-confirm pill and position persistence, branching from saved pills, and the two cases where the board resets (navigate away or undo). Renumbered subsequent steps. Clarified that step 8 (formerly 7) about "Existing line" label naturally applies after confirm.
- **Undo Feedback Lifetime section:** Reworded to remove references to "builder reset" (which no longer happens). Clarified that the snackbar coexists with persistent pills and is dismissed on the first unsaved move, not merely because pills are visible. Added explicit documentation that undo resets to the original starting position.

### `src/lib/controllers/add_line_controller.dart`
- **Refactored `loadData()` into `_loadData({int? leafMoveId})`:** The public `loadData()` is now a thin wrapper that delegates to `_loadData()`. The private method accepts an optional `leafMoveId` parameter. When provided, the engine is created with that move as the `startingMoveId`, populating `_existingPath` with the full root-to-leaf path so all pills appear saved.
- **Updated `_persistMoves()` success path:** After successful persistence, computes the leaf move ID (last inserted move or parent move) and calls `_loadData(leafMoveId: leafMoveId)` instead of `loadData()`. This preserves the board position and pills at the confirmed leaf.
- **Updated `_persistMoves()` error path:** Changed from `await loadData()` to `await _loadData()` (functionally identical but uses the internal method directly for consistency).

### `src/lib/screens/add_line_screen.dart`
- **Updated comment in `_handleConfirmSuccess()`:** Clarified that the board sync now preserves the leaf position rather than resetting to the starting position. No functional change -- the code already reads `_controller.state.currentFen` dynamically.

## Deviations from plan

None. All steps followed the plan exactly. Steps 3-6 confirmed that no functional code changes were needed (as the plan predicted), and Steps 7-9 were already completed in the 3.5 test phase.

## Follow-up work

- **"New Line" / reset button:** There is currently no way to start a completely fresh line without navigating away and back. The plan noted this as an acceptable simplification (Risk 5). Could be a follow-up task if users find it inconvenient.
- **Undo after multiple confirms:** If the user confirms line A, branches and confirms line B, then undoes line B, the state resets to the original starting position rather than showing line A. This is documented as an acceptable UX gap (Risk 6 in the plan). A more sophisticated undo stack could be added later if needed.
- **Visual "just confirmed" indicator:** The plan (Step 10) noted that the existing "Existing line" label is sufficient for v0 but a more prominent indicator (checkmark, different pill styling) could be added as a follow-up.
