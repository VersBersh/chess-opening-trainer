- **Verdict** — `Needs Fixes`
- **Progress**
  - [x] Step 1: Add `onEditLabel` callback to `MoveTreeWidget` — **done**
  - [~] Step 2: Add inline label icon to `_MoveTreeNodeTile` — **partially done**
  - [x] Step 3: Wire callback in `RepertoireBrowserScreen` — **done**
  - [x] Step 4: Retain action bar Label button behavior — **done**
  - [~] Step 5: Add widget tests for inline label icon — **partially done**
  - [x] Step 6: Add integration tests for inline label editing — **done**
  - [ ] Step 7 (optional): Extract shared label dialog — **not started** (optional, acceptable)

- **Issues**
  1. **Major** — Step 2 is not implemented per plan; the row action is a `GestureDetector + Icon`, not the required `IconButton` with compact-but-accessible constraints. In [move_tree_widget.dart](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:241), [move_tree_widget.dart](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:242), and [move_tree_widget.dart](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:245), the current implementation omits the planned `IconButton` semantics and `BoxConstraints(minWidth: 36, minHeight: 36)`, which weakens accessibility/tap-target behavior and deviates from the approved plan.  
     **Suggested fix:** replace this block with an `IconButton` using `icon: Icon(Icons.label_outline, size: 18, color: ...)`, `tooltip: 'Label'`, `onPressed: onEditLabel`, `constraints: const BoxConstraints(minWidth: 36, minHeight: 36)`, and `padding: EdgeInsets.zero`.

  2. **Minor** — Step 5 test coverage does not enforce the planned interaction widget contract (label-related `IconButton` presence/absence). In [move_tree_widget_test.dart](/C:/code/misc/chess-trainer-3/src/test/widgets/move_tree_widget_test.dart:407) and [move_tree_widget_test.dart](/C:/code/misc/chess-trainer-3/src/test/widgets/move_tree_widget_test.dart:417), tests only assert icon visibility, so they would still pass with non-`IconButton` implementations (as happened here).  
     **Suggested fix:** add assertions for `find.byType(IconButton)` scoped to label actions (or `find.widgetWithIcon(IconButton, Icons.label_outline)`) in both the “present” and “absent” cases.