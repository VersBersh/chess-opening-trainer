- **Verdict** — `Approved with Notes`
- **Progress**
  - [x] Step 1 — Add `_pendingLabels` map + read-only accessor
  - [x] Step 2 — Rewrite `updateLabel()` to synchronous local-only behavior
  - [x] Step 3 — Overlay pending labels in `_buildPillsList()`
  - [x] Step 4 — Add `_computeDisplayNameWithPending()` and use it
  - [x] Step 5 — Add `getEffectiveLabelAtPillIndex()`
  - [x] Step 6 — Clear pending labels in `loadData()` and branch path
  - [x] Step 7 — Persist pending label updates atomically with confirm flow
  - [x] Step 8 — Update saved-pill editor `currentLabel` + simplify `onSave`
  - [x] Step 9 — Keep saved/unsaved label-edit paths separate
  - [ ] Step 10 — Verify `hasLineLabel` with pending labels (partially covered; no direct pending-label assertion)
  - [x] Step 11 — Update/add tests for deferred persistence flow and repo/service integration

- **Issues**
  1. **Minor** — Missing direct test for `hasLineLabel` specifically with pending saved-label edits.  
     Files: `src/test/controllers/add_line_controller_test.dart:1485`  
     What’s wrong: The `hasLineLabel` group validates DB/buffered-label paths, but does not explicitly assert behavior when label exists only in `_pendingLabels` (saved pill edited, not yet persisted).  
     Suggested fix: Add a test that sets a pending label via `updateLabel()` on a saved pill and asserts `controller.hasLineLabel == true`, then reverts/removes it and asserts `false` as appropriate.

Implementation is otherwise consistent with the plan, and unplanned changes in other test files are justified by the `RepertoireRepository` interface expansion.