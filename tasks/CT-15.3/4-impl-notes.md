# CT-15.3 Implementation Notes

## Files Modified

- **`src/lib/widgets/browser_action_bar.dart`** -- Added `_ActionDef` data class and `_actions` getter; rewrote `_buildCompact()` and `_buildFullWidth()` to iterate over the shared action list instead of independently enumerating the same 5 actions.

## Deviations from Plan

- **Loss of `const` on `Icon` and `Text` widgets** -- The original code used `const Icon(Icons.add)`, `const Text('Add Line')`, etc. because the values were compile-time constants. In the refactored version, `Icon(action.icon)` and `Text(action.label)` cannot be `const` since the values come from `_ActionDef` fields at runtime. This is an unavoidable consequence of the data-driven approach and has no behavioral or performance impact -- Flutter's widget reconciliation works identically either way.

- No other deviations. All four implementation steps (Steps 1--4) were completed as specified. Step 5 (run tests) was skipped per the task instructions ("Do NOT run the application or tests").

## Follow-up Work

- None discovered. The refactor is purely internal to `BrowserActionBar` with no API changes. The constructor signature is unchanged, so no callers need updating.
