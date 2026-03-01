- **Verdict** — Needs Fixes
- **Issues**
1. **Major — Hidden side effects / lifecycle bug (Clean Code: side effects, SRP)**  
   In [`repertoire_browser_screen.dart:508`](/C:/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart:508), `_showLabelDialog` creates a `TextEditingController` inside the dialog `builder`, and it is never disposed. Because dialog builders can rebuild, this can recreate the controller, reset in-progress input, and leak controller instances.  
   Why it matters: unpredictable UX and memory/resource hygiene issues in a core edit flow.  
   Suggested fix: extract the dialog into a dedicated `StatefulWidget` (or `showDialog` + separate widget) that owns/disposes one controller in `initState`/`dispose`.

2. **Major — Semantic coupling through magic return values (Hidden Coupling / Embedded Design Principle)**  
   `_showLabelDialog` and `_onEditLabel` rely on an implicit contract: `null = cancel`, `'' = remove`, non-empty = save (see [`repertoire_browser_screen.dart:421`](/C:/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart:421) and [`repertoire_browser_screen.dart:563`](/C:/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart:563)).  
   Why it matters: this is brittle and easy to break during future validation/i18n/refactors; behavior depends on caller knowledge, not type-level guarantees.  
   Suggested fix: return a typed result (`cancelled`, `remove`, `save(String)`) via enum/sealed class.

3. **Major — Single Responsibility / file-size smell**  
   [`repertoire_browser_screen.dart`](/C:/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart) is now 811 lines and continues accumulating UI rendering, data loading, edit-mode flow, persistence orchestration, and dialog logic in one state class.  
   Why it matters: high change coupling and reduced maintainability/testability; multiple reasons to change in one class.  
   Suggested fix: extract label editing into a focused component (`LabelEditorDialog` + small coordinator/service), and split screen orchestration from repository operations.

4. **Minor — Test intent vs assertions mismatch (Clean Code: naming, rigor)**  
   In [`repertoire_browser_screen_test.dart:793`](/C:/code/misc/chess-trainer-2/src/test/screens/repertoire_browser_screen_test.dart:793), test name/comment says header update is verified, but no assertion checks the aggregate header.  
   In [`repertoire_browser_screen_test.dart:1010`](/C:/code/misc/chess-trainer-2/src/test/screens/repertoire_browser_screen_test.dart:1010), the “does not rebuild cache” test only checks label unchanged, not rebuild/write behavior.  
   Why it matters: tests communicate stronger guarantees than they actually provide.  
   Suggested fix: either tighten assertions (verify UI header/update call behavior via observable signal) or rename tests to match what is truly verified.

5. **Minor — Additional file-size smells in modified files (Clean Code)**  
   Modified files over 300 lines: [`repertoire_browser_screen_test.dart`](/C:/code/misc/chess-trainer-2/src/test/screens/repertoire_browser_screen_test.dart) (1042), [`drill_screen_test.dart`](/C:/code/misc/chess-trainer-2/src/test/screens/drill_screen_test.dart) (661), [`home_screen_test.dart`](/C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart) (402).  
   Why it matters: discoverability and maintenance costs rise; behavior is harder to reason about in large monolithic test files.  
   Suggested fix: split by feature group (`label_editing`, `edit_mode`, `navigation`, etc.) into separate test files.