- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden coupling + accessibility semantics (Clean Code: side effects, Embedded Design clarity)**  
   In [`move_tree_widget.dart:241`](C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:241) the inline label action is implemented as `GestureDetector` + `Icon` inside a row-level `InkWell` ([`move_tree_widget.dart:168`](C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:168)).  
   Why it matters: this relies on gesture-arena behavior to avoid also triggering row selection, and it does not expose button semantics/focus behavior or a robust tap target. The interaction contract is implicit rather than encoded in the widget type.  
   Suggested fix: replace with `IconButton` (or `IconButton.filledTonal` if desired) with explicit `tooltip`, compact constraints, and padding. Add tests proving icon tap does **not** trigger node selection (currently only the inverse is tested in [`move_tree_widget_test.dart:437`](C:/code/misc/chess-trainer-3/src/test/widgets/move_tree_widget_test.dart:437)).

2. **Minor — File-size / responsibility smell (SRP, Clean Code: file size, architecture readability)**  
   Modified files are significantly over the 300-line smell threshold:  
   - [`repertoire_browser_screen.dart`](C:/code/misc/chess-trainer-3/src/lib/screens/repertoire_browser_screen.dart) (~1005 lines)  
   - [`repertoire_browser_screen_test.dart`](C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart) (~1445 lines)  
   - [`move_tree_widget_test.dart`](C:/code/misc/chess-trainer-3/src/test/widgets/move_tree_widget_test.dart) (~499 lines)  
   Why it matters: architecture intent is harder to read, and unrelated responsibilities (loading, board controls, dialogs, deletion/orphan logic, label flows) are tightly co-located.  
   Suggested fix: split by behavior slices (e.g., label dialog/actions, deletion/orphan flows, board/navigation controls) and split tests into focused files per feature area.