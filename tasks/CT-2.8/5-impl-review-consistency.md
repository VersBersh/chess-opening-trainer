- **Verdict** — Needs Fixes
- **Progress**
  - [x] Step 1 — Add `ConfirmError` result type (done)
  - [x] Step 2 — Move `sqlite3` to `dependencies` (done)
  - [x] Step 3 — Add/implement `saveBranch()` in repository layer (done)
  - [x] Step 4 — Update `_persistMoves()` Path B to use `saveBranch()` (done)
  - [x] Step 5 — Wrap `_persistMoves()` in try/catch with SQLite unwrap + reload (done)
  - [x] Step 6 — Handle `ConfirmError` in `_onConfirmLine()` (done)
  - [x] Step 7 — Handle `ConfirmError` in `_onFlipAndConfirm()` (done)
  - [~] Step 8 — Controller tests for error handling/atomicity (partially done: 2/3 implemented)
  - [~] Step 9 — Widget tests for error SnackBars (partially done: 1/2 implemented)

- **Issues**
  1. **Major** — Missing atomicity regression test for branch save path (plan Step 8.3).  
     Evidence: the `Confirm error handling` group includes only duplicate-message and state-consistency tests, with no DB-assertion that partial branch inserts are rolled back on constraint failure. See [add_line_controller_test.dart:897](C:/code/misc/chess-trainer-1/src/test/controllers/add_line_controller_test.dart:897).  
     Why it matters: the core risk in this task was partial writes in Path B; without an explicit atomicity test, future changes could silently reintroduce data corruption.  
     Suggested fix: add a test that intentionally triggers a mid-branch failure and then asserts no newly inserted branch moves remain in `repertoire_moves` and no dangling review card exists.

  2. **Major** — Missing widget test for `_onFlipAndConfirm()` error SnackBar (plan Step 9.2).  
     Evidence: only confirm-path SnackBar test was added; there is no parity-warning “Flip and confirm” error-path test. See [add_line_screen_test.dart:959](C:/code/misc/chess-trainer-1/src/test/screens/add_line_screen_test.dart:959).  
     Why it matters: `_onFlipAndConfirm()` has separate control flow; this is exactly where regressions in mounted checks or result handling can hide.  
     Suggested fix: add a widget test that triggers parity mismatch, injects duplicate constraint, taps “Flip and confirm…”, and verifies the same error SnackBar text.

  3. **Minor** — `saveBranch()` assumes `newMoves` is non-empty via `parentId!` and has no explicit contract guard.  
     Evidence: null assertion at [local_repertoire_repository.dart:192](C:/code/misc/chess-trainer-1/src/lib/repositories/local/local_repertoire_repository.dart:192).  
     Why it matters: current callers likely pass non-empty lists, but this is an implicit invariant; a future caller could trigger a runtime `NullThrownError`/assertion failure.  
     Suggested fix: add `assert(newMoves.isNotEmpty)` (and/or a defensive early throw with clear message) at method entry.