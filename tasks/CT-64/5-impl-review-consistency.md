- **Verdict** — `Approved with Notes`
- **Progress**
  - [x] Step 1: Added `_hasConfirmedSinceLastReset` and `canResetForNewLine` in the controller, with the flag cleared in `loadData()` and set on successful confirm paths.
  - [x] Step 2: Added `resetForNewLine()` to invalidate undo state and reload to the starting position.
  - [~] Step 3: Added `_onNewLine()` and conditionally rendered the button, but the button is placed after `Label` instead of after `Confirm` as specified in the plan.
  - [x] Step 4: Added the planned controller tests, plus an extra `startingMoveId` reset case.
  - [~] Step 5: Added the planned widget-test group and most scenarios, but two planned assertions are only partially covered.

- **Issues**
  1. Minor — [add_line_screen.dart#L930](/C:/code/draftable/chess-3/src/lib/screens/add_line_screen.dart#L930) and [add_line_screen.dart#L944](/C:/code/draftable/chess-3/src/lib/screens/add_line_screen.dart#L944)  
     Step 3b said to insert the conditional `New Line` action immediately after `Confirm`, but the implementation appends it after `Label`. This is functionally harmless, but it is a plan deviation and changes the reviewed action order. Fix by moving the conditional `TextButton.icon` block above the `Label` button, or update the plan/notes if this was intentional.

  2. Minor — [add_line_screen_test.dart#L3502](/C:/code/draftable/chess-3/src/test/screens/add_line_screen_test.dart#L3502)  
     The `"tapping New Line resets board and pills to starting position"` widget test checks pills, helper text, button state, and button visibility, but it never asserts the board FEN. That leaves Step 5d only partially verified at widget level. Fix by reading the pumped `Chessboard` and asserting its `fen` is `kInitialFEN` after reset.

  3. Minor — [add_line_screen_test.dart#L3610](/C:/code/draftable/chess-3/src/test/screens/add_line_screen_test.dart#L3610)  
     The test titled `"New Line clears label editor and parity warning"` only exercises the label-editor path; it never creates or asserts a parity warning. That makes the test name misleading and leaves the parity-warning portion of Step 5g uncovered. Fix by either renaming the test to match what it actually covers or adding a separate reachable parity-warning assertion.

The controller and screen changes themselves look logically correct, handle the important reset/undo/orientation cases, and do not show any obvious caller regressions.