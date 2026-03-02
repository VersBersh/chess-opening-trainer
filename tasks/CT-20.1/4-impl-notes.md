# CT-20.1 Implementation Notes

## Files Modified

- `src/lib/repositories/local/local_review_repository.dart` — Replaced inline ISO 8601 string interpolation in `getCardsForSubtree` with parameterized `Variable<DateTime>` binding. The `dueFilter` now uses a `?` placeholder, and the variables list conditionally includes `Variable<DateTime>(cutoff)` when `dueOnly` is true.

## Deviations from Plan

None. The change was a straightforward substitution as described in Step 1.

## New Tasks / Follow-up Work

None discovered. Test hardening is already covered by CT-20.3.
