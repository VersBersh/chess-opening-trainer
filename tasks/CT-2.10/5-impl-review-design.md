- **Verdict** — `Approved with Notes`

- **Issues**
1. **Major — Hidden Coupling / Control-Flow-by-Exception**
   - **Where:** [`repertoire_browser_screen.dart:234`](C:/code/misc/chess-trainer-3/src/lib/screens/repertoire_browser_screen.dart:234), [`add_line_screen.dart:377`](C:/code/misc/chess-trainer-3/src/lib/screens/add_line_screen.dart:377), [`repertoire_dialogs.dart:13`](C:/code/misc/chess-trainer-3/src/lib/widgets/repertoire_dialogs.dart:13), [`inline_label_editor.dart:97`](C:/code/misc/chess-trainer-3/src/lib/widgets/inline_label_editor.dart:97)
   - **What:** Canceling the warning dialog is implemented by throwing `LabelChangeCancelledException`, which relies on `InlineLabelEditor._confirmEdit()` catching all exceptions to keep the editor open.
   - **Why it matters:** This creates semantic coupling across UI modules and conflates expected cancellation with real save failures, making behavior brittle and harder to reason about (temporal/semantic coupling).
   - **Suggested fix:** Replace exception-based cancellation with an explicit result contract from `onSave` (e.g., `SaveOutcome.saved/cancelled/failed` or `Future<bool>`), and reserve exceptions for actual errors.

2. **Minor — DRY / Single Source of Truth for Label Aggregation**
   - **Where:** [`repertoire.dart:138`](C:/code/misc/chess-trainer-3/src/lib/models/repertoire.dart:138), [`repertoire.dart:210`](C:/code/misc/chess-trainer-3/src/lib/models/repertoire.dart:210), [`repertoire.dart:244`](C:/code/misc/chess-trainer-3/src/lib/models/repertoire.dart:244)
   - **What:** Aggregate display-name construction logic is duplicated (`previewAggregateDisplayName` and `_previewDescendantDisplayName`).
   - **Why it matters:** Future changes to label formatting rules can drift between paths.
   - **Suggested fix:** Extract one private helper that builds aggregate labels with optional override (`changedMoveId`, `newLabel`) and reuse it in both methods.

3. **Minor — File Size Code Smell**
   - **Where:** [`add_line_screen.dart`](C:/code/misc/chess-trainer-3/src/lib/screens/add_line_screen.dart) (445 lines), [`repertoire_browser_screen.dart`](C:/code/misc/chess-trainer-3/src/lib/screens/repertoire_browser_screen.dart) (308), [`repertoire_tree_cache_test.dart`](C:/code/misc/chess-trainer-3/src/test/models/repertoire_tree_cache_test.dart) (516), [`add_line_screen_test.dart`](C:/code/misc/chess-trainer-3/src/test/screens/add_line_screen_test.dart) (1001), [`repertoire_browser_screen_test.dart`](C:/code/misc/chess-trainer-3/src/test/screens/repertoire_browser_screen_test.dart) (1889)
   - **What:** Multiple modified files exceed 300 lines.
   - **Why it matters:** Large files reduce readability and increase change risk.
   - **Suggested fix:** Split screen files by feature sections (label editing, deletion flows, dialogs) and split tests by behavior group into multiple files.