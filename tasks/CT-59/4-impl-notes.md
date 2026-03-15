# CT-59: Implementation Notes

## Files modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | Added `hasPendingLabelChanges`, `hasUnsavedChanges` getters; updated `isExistingLine`; updated `confirmAndPersist()` and `flipAndConfirm()` guards for label-only path; added `_persistLabelsOnly()` delegating to `_loadData(preservePosition: true)`; extracted `_buildPendingLabelUpdates()` helper; added `preservePosition` param to `_loadData()` |
| `src/lib/screens/add_line_screen.dart` | Changed Confirm button, `_onConfirmLine` guard, and `PopScope.canPop` from `hasNewMoves` to `hasUnsavedChanges`; updated discard dialog text to "unsaved changes" |
| `src/lib/services/line_persistence_service.dart` | Added `persistLabelsOnly()` method using existing `updateMoveLabel` in a loop |

## Files not modified (no changes needed per plan)

| File | Reason |
|------|--------|
| `src/lib/services/line_entry_engine.dart` | Engine remains unaware of pending labels (by design) |
| `src/lib/widgets/move_pills_widget.dart` | No changes needed |
| `src/lib/repositories/repertoire_repository.dart` | No new abstract methods needed — reuses existing `updateMoveLabel` |
| `src/lib/repositories/local/local_repertoire_repository.dart` | No changes needed |

## Deviations from plan

1. **No `batchUpdateLabels` on repository** — Code review flagged interface segregation: adding a method to the shared `RepertoireRepository` forced all 5 unrelated test fakes to implement it. Instead, `LinePersistenceService.persistLabelsOnly` loops over existing `updateMoveLabel`. For 1-2 labels this is acceptable.
2. **`_persistLabelsOnly` delegates to `_loadData`** — Code review flagged duplicated state-rebuild logic. Refactored to add `preservePosition` parameter to `_loadData()` and delegate to it, eliminating the bespoke rebuild.
3. **Extracted `_buildPendingLabelUpdates` helper** — Shared between `_persistLabelsOnly` and `_persistMoves` to eliminate duplication.
4. **Discard dialog wording updated** — Changed from "unsaved moves" to "unsaved changes" to match the broadened semantics.

## Follow-up work discovered

1. **Label-only confirm feedback:** The label-only path produces `ConfirmSuccess` with empty `insertedMoveIds`, which correctly skips undo snackbars. However, the user gets no explicit feedback that labels were saved. A brief "Labels saved" snackbar could be added for user reassurance.
