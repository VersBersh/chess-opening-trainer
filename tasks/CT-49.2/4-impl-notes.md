# CT-49.2: Implementation Notes

## Files Modified

- **`src/lib/services/line_entry_engine.dart`** — Extended `canTakeBack()` to check all three lists (buffered, followed, existing-path). Replaced `takeBack()` with 3-phase pop logic that walks buffer -> followed -> existing-path, keeping `_lastExistingMoveId` in sync. Updated doc comments on both methods.

- **`src/lib/controllers/add_line_controller.dart`** — Updated doc comment on `onTakeBack()` to reflect that it now removes any visible pill (not just buffered moves). No production logic changes needed; the controller already rebuilds pills via `_buildPillsList(engine)` and falls back to `setPosition` when board undo history is empty.

- **`src/test/services/line_entry_engine_test.dart`** — Updated "Take-back removes buffered moves only" test to expect `canTakeBack() == true` after clearing buffer (followed move still present) and added take-back of the followed move. Updated "Take-back at branch boundary" test from `false` to `true` with full followed-move take-back assertions. Added new "Take-back through all pill types" group with 4 tests: followed-move lastExistingMoveId tracking, existing-path pop-through, take-back-then-branch divergence, and canTakeBack boundary condition.

- **`src/test/controllers/add_line_controller_test.dart`** — Changed `expect(controller.canTakeBack, false)` to `true` in the `updateLabel` branching test (line ~837). Added new "Take-back through followed moves" group with 2 tests: pills shrink and board updates correctly when taking back followed moves; take-back followed moves then playing a new move creates a branch with unsaved pill.

## Files Created

- **`tasks/CT-49.2/4-impl-notes.md`** — This file.

## Deviations from Plan

None. All 7 steps were implemented as specified.

## Follow-up Work / Observations

1. **Existing-path take-back in controller tests:** The new engine tests cover existing-path pop-through thoroughly, but the controller test group only tests take-back through followed moves (not existing-path moves). This is acceptable because the controller delegates entirely to the engine and the engine tests cover the existing-path case. A controller-level test could be added later for completeness if desired.

2. **`_hasDiverged` is not reset when taking back followed/existing moves:** This is correct behavior since `_hasDiverged` is only meaningful when the buffer is non-empty. When the buffer is empty, `_hasDiverged` is already `false`. No issue, but worth noting for future readers.
