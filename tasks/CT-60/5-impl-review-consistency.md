**Verdict** — `Approved with Notes`

**Progress**
- [x] Step 1: `_onConfirmLine()` now distinguishes `"Add name"` (`false`) from dialog dismiss (`null`) and re-opens the inline label editor with a `mounted` guard.
- [x] Step 2: The existing `"Add name" does not persist and stays on screen` test now checks that `InlineLabelEditor` is shown.
- [ ] Step 3: Partially done. A non-leaf-focused `"Add name"` test was added, but it does not prove the editor opened for the earlier-focused pill specifically.
- [x] Step 4: The parity short-circuit test now asserts against the real parity warning text instead of the old false-positive string.

**Issues**
1. Minor — The new non-leaf coverage is weaker than the plan intended. In [src/test/screens/add_line_screen_test.dart](/C:/code/draftable/chess-1/src/test/screens/add_line_screen_test.dart):2033 and [src/test/screens/add_line_screen_test.dart](/C:/code/draftable/chess-1/src/test/screens/add_line_screen_test.dart):2051, the test taps `e4` and then only asserts that some `InlineLabelEditor` is visible. But the editor is selected from the current `focusedPillIndex` in [src/lib/screens/add_line_screen.dart](/C:/code/draftable/chess-1/src/lib/screens/add_line_screen.dart):665 and keyed by the focused unsaved pill index in [src/lib/screens/add_line_screen.dart](/C:/code/draftable/chess-1/src/lib/screens/add_line_screen.dart):730. That means the test would still pass if a regression reset focus back to the leaf before reopening the editor. Fix by asserting the focus moved to index `0` before confirm and/or by checking for `ValueKey('label-editor-unsaved-0')` after tapping `"Add name"`.