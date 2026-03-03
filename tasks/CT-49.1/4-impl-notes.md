# CT-49.1: Deferred Label Persistence -- Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | Added `_pendingLabels` map with public accessor; rewrote `updateLabel()` from async DB-write to synchronous local-only; added `_getOriginalLabel()`, `_computeDisplayNameWithPending()`, `getEffectiveLabelAtPillIndex()` helpers; overlay pending labels in `_buildPillsList()`; clear `_pendingLabels` in `loadData()` and `onBoardMove()` branching path; build `PendingLabelUpdate` list in `_persistMoves()` and pass to persistence service; updated docstrings; replaced all `engine.getCurrentDisplayName()` calls with `_computeDisplayNameWithPending(engine)`. |
| `src/lib/screens/add_line_screen.dart` | Updated `_buildSavedPillLabelEditor()` to use `getEffectiveLabelAtPillIndex()` for `currentLabel`; simplified `onSave` callback to call synchronous `updateLabel()` without `await` or board reset. |
| `src/lib/services/line_persistence_service.dart` | Added `PendingLabelUpdate` data class; updated `persistNewMoves()`, `_persistExtension()`, and `_persistBranch()` to accept optional `pendingLabelUpdates` parameter and delegate to new `WithLabelUpdates` repository methods when non-empty. |
| `src/lib/repositories/repertoire_repository.dart` | Added import for `line_persistence_service.dart`; added abstract methods `extendLineWithLabelUpdates()` and `saveBranchWithLabelUpdates()`. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Added import for `line_persistence_service.dart`; implemented `extendLineWithLabelUpdates()` and `saveBranchWithLabelUpdates()` with label updates + move inserts in a single DB transaction. |
| `src/test/controllers/add_line_controller_test.dart` | Renamed `'Label update'` group to `'Label update (deferred persistence)'`; updated all existing label tests to use synchronous `updateLabel()` (removed `await`); changed assertions from DB-verification to `pendingLabels` verification; added new tests: `updateLabel stores pending label`, `updateLabel with original value removes entry`, `_buildPillsList overlays pending labels`, `getEffectiveLabelAtPillIndex` (3 tests), `confirmAndPersist persists pending labels atomically`, `pending labels cleared after confirm`, `pending labels discarded on abandon`, `pending labels cleared on branch`. |
| `src/test/services/line_persistence_service_test.dart` | Added test group `'Persistence with pending label updates'` with three tests: extension with label updates, branch with label updates, and no-label-updates fallback to original methods. |

## Deviations from Plan

1. **`PendingLabelUpdate` moved to repository layer**: The plan initially placed `PendingLabelUpdate` in `line_persistence_service.dart`, causing a dependency inversion (repository importing service). During code review this was moved to `repertoire_repository.dart` where it belongs.

2. **`updateLabel()` guard added**: Code review identified that `updateLabel()` didn't enforce the saved-pill precondition. An early-return guard was added for out-of-range or buffered pill indices.

3. **`newEngine.getCurrentDisplayName()` in branching path**: The global replace of `engine.getCurrentDisplayName()` did not catch the variable named `newEngine` in the branching path of `onBoardMove()`. This was fixed manually and combined with the `_pendingLabels.clear()` insertion for that path.

## Follow-up Work

1. **Label-only edits with no new moves**: As noted in the plan's risks, if the user follows an existing line and only edits labels (no new moves), the Confirm button remains disabled and pending labels are silently discarded. A follow-up task could enable Confirm when `_pendingLabels.isNotEmpty` even without new moves.

2. **Display name preview accuracy**: The `previewDisplayName` callback for saved pills still uses `cache.previewAggregateDisplayName(move.id, text)`, which does not account for pending labels on other pills. The aggregate banner above the board does show the full pending-aware display name.

3. **Repository code duplication**: `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates` duplicate the core transaction logic from `extendLine`/`saveBranch`. A private helper could extract the shared insert-chain logic to reduce duplication.
