**Verdict** — Approved with Notes

**Issues**
1. **Major — Data structure invariant not enforced (Clean Code / Hidden Coupling)**  
   In [`move_tree_widget.dart:25`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:25), `VisibleNode` documents that `moves` is always non-empty, but this is not enforced while [`firstMove`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:32) / [`lastMove`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:33) assume it.  
   Why it matters: this creates a silent temporal/semantic contract between constructors and consumers; a future caller can create `VisibleNode(moves: [])` and trigger runtime failures.  
   Suggested fix: add `assert(moves.isNotEmpty)` in the constructor (and optionally expose an unmodifiable view).

2. **Minor — Single file owns too many responsibilities and exceeds size threshold (SRP / Embedded Design Principle)**  
   [`move_tree_widget.dart`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart) is now 349 lines and contains model (`VisibleNode`), tree flattening (`buildVisibleNodes`), notation formatting (`buildChainNotation`), and UI rendering (`MoveTreeWidget`, `_MoveTreeNodeTile`) at [`15`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:15), [`45`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:45), [`92`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:92), [`128`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:128), [`200`](/C:/code/misc/chess-trainer-3/src/lib/widgets/move_tree_widget.dart:200).  
   Why it matters: architecture is harder to read and extend; changes to formatting/tree logic risk unintended UI coupling.  
   Suggested fix: split into small units (`visible_node.dart`, `move_tree_flattening.dart`, `move_notation_formatter.dart`, widget file).

3. **Minor — Test intent no longer matches behavior (Naming / Embedded Design Principle)**  
   In [`repertoire_browser_screen_test.dart:765`](/C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:765), test name says “root, interior, and leaf,” but comments/code at [`790`](/C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:790) and [`801`](/C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart:801) explicitly switch to labeling a leaf instead of an interior node.  
   Why it matters: misleading test names reduce trust in test coverage and obscure design intent.  
   Suggested fix: either rename test to match actual coverage, or adjust setup to truly label an interior node (e.g., via inline row label icon on a chain where first move is interior).