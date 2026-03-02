# CT-12.1: Always seed review cards in debug mode -- Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/services/dev_seed.dart` | Restructured `seedDevData` into two branches (create vs. ensure-due). Extracted seed creation into `_createSeedRepertoire`. Added `_ensureCardsDueToday` to make up to 4 seed cards due on every debug launch. Added `_devSeedRepertoireName` constant. |

## Files Created

None.

## Deviations from Plan

None. All six steps were followed exactly as specified.

## Follow-up Work

None discovered during implementation. The plan was self-contained and all referenced APIs (`toCompanion`, `copyWith`, `getDueCardsForRepertoire`, `getAllCardsForRepertoire`, `saveReview` with `id.present` for update) already exist in the codebase and match the usage in the implementation.
