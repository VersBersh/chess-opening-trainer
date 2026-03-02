- **Verdict** — `Needs Fixes`

- **Issues**
1. **Major — Hidden Coupling / Temporal Coupling:** Parity-warning state can become stale because invalidation is manually scattered and not tied to line-position changes.  
   Code sets warning in [`add_line_screen.dart:136`](/C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart:136), renders it in [`add_line_screen.dart:339`](/C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart:339), and clears it in some handlers (`_onBoardMove`, `_onTakeBack`, `_onFlipBoard`) but not in pill navigation [`add_line_screen.dart:109`](/C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart:109). A user can change position via pill tap while still seeing an old mismatch message/action.  
   Why it matters: warning semantics depend on current line context; stale warnings create incorrect guidance and fragile behavior as more navigation actions are added.  
   Suggested fix: centralize invalidation for all position-changing actions (including pill taps), or store warning with a context token (for example FEN/pill index at creation) and auto-hide when context no longer matches.

2. **Major — Single Responsibility / Embedded Design Clarity / File Size Smell:** `AddLineScreen` has grown into a UI orchestration “god class” (426 lines), mixing board orchestration, transient UI state, warning composition, confirm workflow, undo snackbar, discard dialog, and label editing.  
   See full file [`add_line_screen.dart`](/C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart).  
   Why it matters: this increases reasons to change, makes behavior coupling harder to see, and reduces extension safety (OCP pressure on one class).  
   Suggested fix: extract parity-warning presentation + actions into a dedicated widget/controller adapter, and move transient-state coordination into a focused view-model-style helper.

3. **Minor — DRY / Test Maintainability / File Size Smell:** The test file is very large (833 lines) and the new parity tests duplicate the same setup/action flow repeatedly (play `e4/e5`, confirm, assert warning) across multiple cases (for example around [`add_line_screen_test.dart:825`](/C:/code/misc/chess-trainer-4/src/test/screens/add_line_screen_test.dart:825), [`add_line_screen_test.dart:897`](/C:/code/misc/chess-trainer-4/src/test/screens/add_line_screen_test.dart:897), [`add_line_screen_test.dart:956`](/C:/code/misc/chess-trainer-4/src/test/screens/add_line_screen_test.dart:956)).  
   Why it matters: duplicated test choreography raises maintenance cost and obscures scenario intent.  
   Suggested fix: extract helpers like `triggerParityMismatchWarning()` and split screen tests by concern (parity, labeling, navigation, undo).