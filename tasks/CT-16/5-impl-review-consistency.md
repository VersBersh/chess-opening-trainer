- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] Step 1: Add `viewportSize` to drill `buildTestApp` (`done`)
  - [x] Step 2: Add `viewportSize` to repertoire browser `buildTestApp` (`done`)
  - [x] Step 3: Add narrow drill layout tests (`done`, with stated assertion-strategy deviation)
  - [x] Step 4: Add wide drill layout tests (`done`, with stated assertion-strategy deviation)
  - [ ] Step 5: Add wide repertoire browser tests (`partially done`)

- **Issues**
  1. **Major** — Step 5 is missing planned tooltip/accessibility assertions for compact action bar behavior.  
     The plan explicitly requires validating wide-mode tooltips (`Add Line`, `Import`, `Label`, `Stats`), plus delete tooltip state (`Delete Branch` with no selection, then `Delete` on leaf). Current tests only check `Add Line` tooltip once and otherwise rely mostly on icon presence / enabled state.  
     Affected lines: [src/test/screens/repertoire_browser_screen_test.dart:1470](C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:1470), [src/test/screens/repertoire_browser_screen_test.dart:1491](C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:1491), [src/test/screens/repertoire_browser_screen_test.dart:1520](C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:1520)  
     Suggested fix: add assertions using `find.byTooltip(...)` for all compact buttons and explicitly assert delete tooltip transitions (`Delete Branch` before selection, `Delete` after selecting a leaf).

  2. **Minor** — Drill branch-distinguishing assertions deviate from the planned checks and do not assert the specific row-vs-column/action-bar distinctions requested in the plan.  
     Current approach checks `LayoutBuilder` ancestry instead of the planned structural assertions. It likely works today, but it is less aligned with the explicit plan text.  
     Affected lines: [src/test/screens/drill_screen_test.dart:1657](C:/code/misc/chess-trainer-3/src/test/screens/drill_screen_test.dart:1657), [src/test/screens/drill_screen_test.dart:1762](C:/code/misc/chess-trainer-3/src/test/screens/drill_screen_test.dart:1762)  
     Suggested fix: either add the original plan assertions (row/column and control-surface distinctions) or update the plan to formally accept `LayoutBuilder`-based branch detection as the intended strategy.