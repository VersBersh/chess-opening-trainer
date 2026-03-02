- **Verdict** — Needs Fixes

- **Issues**
1. **Major — Hidden temporal coupling / side effects on dismiss**  
   [inline_label_editor.dart:70](C:/code/misc/chess-trainer-4/src/lib/widgets/inline_label_editor.dart:70), [inline_label_editor.dart:76](C:/code/misc/chess-trainer-4/src/lib/widgets/inline_label_editor.dart:76), [add_line_screen.dart:109](C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart:109), [repertoire_browser_screen.dart:80](C:/code/misc/chess-trainer-4/src/lib/screens/repertoire_browser_screen.dart:80)  
   `InlineLabelEditor` auto-saves on any focus loss, while both screens implement “dismiss on different selection/navigation” by removing the editor. That creates event-order coupling: a dismiss interaction can still trigger `_confirmEdit()` depending on focus/unmount timing. This violates predictable behavior and couples parent dismissal semantics to child focus internals.  
   **Fix:** separate explicit “commit” vs “dismiss” paths. Examples: expose `commitOnBlur` flag, or have parent call an explicit `dismissWithoutSave` path before unmount; only save on Enter/explicit confirm.

2. **Major — Save failure handling closes editor and drops user input**  
   [inline_label_editor.dart:90](C:/code/misc/chess-trainer-4/src/lib/widgets/inline_label_editor.dart:90), [inline_label_editor.dart:92](C:/code/misc/chess-trainer-4/src/lib/widgets/inline_label_editor.dart:92)  
   `onClose()` is called in `finally`, so the editor closes even when `onSave` throws. That is a hidden side effect and poor failure isolation: users can lose edits with no recovery path.  
   **Fix:** catch save errors, keep editor open, re-enable input, and surface error (snackbar/inline message). Call `onClose()` only on successful save or intentional cancel.

3. **Minor — Test intent/name does not match behavior**  
   [add_line_screen_test.dart:586](C:/code/misc/chess-trainer-4/src/test/screens/add_line_screen_test.dart:586)  
   Test `"take-back while editor is open closes the editor"` never taps “Take Back”; it only asserts editor is open. This weakens architecture-level confidence in dismissal rules and makes the test misleading.  
   **Fix:** either execute the take-back flow in a state where it is enabled, or rename the test to reflect what it actually verifies.

4. **Minor — File size smell (maintainability / SRP pressure)**  
   [add_line_screen.dart](C:/code/misc/chess-trainer-4/src/lib/screens/add_line_screen.dart), [repertoire_browser_screen.dart](C:/code/misc/chess-trainer-4/src/lib/screens/repertoire_browser_screen.dart), [add_line_screen_test.dart](C:/code/misc/chess-trainer-4/src/test/screens/add_line_screen_test.dart), [repertoire_browser_screen_test.dart](C:/code/misc/chess-trainer-4/src/test/screens/repertoire_browser_screen_test.dart)  
   Modified files are 421, 712, 659, and 1509 lines respectively. This exceeds your >300-line smell threshold and makes responsibilities harder to reason about.  
   **Fix:** extract screen sections into focused widgets/builders and split test suites by feature area (label editing, navigation, deletion, etc.).